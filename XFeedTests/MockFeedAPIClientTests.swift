import Testing
import Foundation
@testable import XFeed

struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@Suite struct MockFeedAPIClientTests {
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    func makeSUT(failureRate: Double = 0, seed: SeedData? = nil) throws -> MockFeedAPIClient {
        MockFeedAPIClient(
            seed: try seed ?? SeedData.load(from: .main),
            config: MockConfig(failureRate: failureRate, minLatency: 0, maxLatency: 0),
            random: SeededGenerator(seed: 1),
            now: { now },
            sleep: { _ in })
    }

    func allPages(_ sut: MockFeedAPIClient, limit: Int = 10) async throws -> [[PostDTO]] {
        var pages: [[PostDTO]] = []
        var cursor: String?
        repeat {
            let page = try await sut.fetchFeed(cursor: cursor, limit: limit)
            pages.append(page.posts)
            cursor = page.nextCursor
        } while cursor != nil
        return pages
    }

    @Test func pagesThroughAll50SeedsNewestFirstWithoutDuplicates() async throws {
        let pages = try await allPages(try makeSUT())

        #expect(pages.map(\.count) == [10, 10, 10, 10, 10])
        let all = pages.flatMap { $0 }
        #expect(Set(all.map(\.id)).count == 50)
        let dates = all.map(\.createdAt)
        #expect(dates == dates.sorted(by: >))
    }

    @Test func lastPageHasNoCursor() async throws {
        let sut = try makeSUT()
        let pages = try await allPages(sut, limit: 25)
        #expect(pages.count == 2)
        #expect(pages.last?.count == 25)
    }

    @Test func createdPostAppearsAtTopAndDoesNotShiftLaterPages() async throws {
        let sut = try makeSUT()
        let first = try await sut.fetchFeed(cursor: nil, limit: 10)

        let created = try await sut.createPost(CreatePostRequestDTO(text: "brand new", imageURL: nil))
        let refreshed = try await sut.fetchFeed(cursor: nil, limit: 10)
        let second = try await sut.fetchFeed(cursor: first.nextCursor, limit: 10)

        #expect(refreshed.posts.first?.id == created.id)
        #expect(created.author.id == "me")
        #expect(created.createdAt == now)
        #expect(second.posts.first?.id == "post-011")
        #expect(Set(second.posts.map(\.id)).isDisjoint(with: first.posts.map(\.id)))
    }

    @Test func setLikeIsIdempotent() async throws {
        let sut = try makeSUT()
        let before = try await sut.fetchFeed(cursor: nil, limit: 50).posts.first { !$0.isLikedByMe }!

        let once = try await sut.setLike(postID: before.id, liked: true)
        let twice = try await sut.setLike(postID: before.id, liked: true)
        let undone = try await sut.setLike(postID: before.id, liked: false)

        #expect(once.likeCount == before.likeCount + 1 && once.isLikedByMe)
        #expect(twice == once)
        #expect(undone.likeCount == before.likeCount && !undone.isLikedByMe)
    }

    @Test func setLikeOnUnknownPostThrowsNotFound() async throws {
        let sut = try makeSUT()
        await #expect(throws: FeedAPIError.notFound) {
            try await sut.setLike(postID: "nope", liked: true)
        }
    }

    @Test func failureRateOneAlwaysFails() async throws {
        let sut = try makeSUT(failureRate: 1)
        await #expect(throws: FeedAPIError.self) { try await sut.fetchFeed(cursor: nil, limit: 10) }
        await #expect(throws: FeedAPIError.self) { try await sut.setLike(postID: "post-001", liked: true) }
        await #expect(throws: FeedAPIError.self) {
            try await sut.createPost(CreatePostRequestDTO(text: "x", imageURL: nil))
        }
    }

    @Test func failedCreateDoesNotStoreThePost() async throws {
        let sut = try makeSUT()
        await sut.update(MockConfig(failureRate: 1, minLatency: 0, maxLatency: 0))
        _ = try? await sut.createPost(CreatePostRequestDTO(text: "x", imageURL: nil))
        await sut.update(MockConfig(failureRate: 0, minLatency: 0, maxLatency: 0))

        #expect(try await allPages(sut).flatMap { $0 }.count == 50)
    }

    @Test func forceNextRequestToFailFailsExactlyOnce() async throws {
        let sut = try makeSUT()
        await sut.forceNextRequestToFail()

        await #expect(throws: FeedAPIError.self) { try await sut.fetchFeed(cursor: nil, limit: 10) }
        _ = try await sut.fetchFeed(cursor: nil, limit: 10)
    }

    @Test func resetRestoresSeedData() async throws {
        let sut = try makeSUT()
        _ = try await sut.createPost(CreatePostRequestDTO(text: "x", imageURL: nil))
        _ = try await sut.setLike(postID: "post-001", liked: true)

        await sut.resetToSeedData()

        let all = try await allPages(sut).flatMap { $0 }
        #expect(all.count == 50)
        #expect(all.first?.id == "post-001")
    }

    @Test func updateChangesConfig() async throws {
        let sut = try makeSUT()
        let config = MockConfig(failureRate: 0.5, minLatency: 1, maxLatency: 2)
        await sut.update(config)
        #expect(await sut.currentConfig() == config)
    }

    @Test func seedFileHas50PostsWithExpectedShape() throws {
        let seed = try SeedData.load(from: .main)
        #expect(seed.posts.count == 50)
        #expect(seed.posts.filter { $0.imageURL != nil }.count == 29)
        #expect(seed.posts.map(\.text.count).max() == 277)
    }
}
