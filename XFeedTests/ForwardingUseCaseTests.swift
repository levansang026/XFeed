import Testing
@testable import XFeed

@MainActor
@Suite struct ForwardingUseCaseTests {
    @Test func loadFeedForwardsCursorWithDefaultPageSizeOfTen() async throws {
        let repo = FakeFeedRepository()
        nonisolated(unsafe) var limit = 0
        repo.onFeed = { _, l in limit = l; return TestData.page(1...2, next: "n") }

        let page = try await LoadFeed(repository: repo)(cursor: "c")

        #expect(repo.feedCursors == ["c"] && limit == 10)
        #expect(page.nextCursor == "n")
    }

    @Test func setLikeForwardsDesiredStateAndReturnsServerPost() async throws {
        let repo = FakeFeedRepository()
        repo.onLike = { id, liked in TestData.post(id: id, likeCount: 7, isLiked: liked) }

        let post = try await SetLike(repository: repo)(postID: "p9", liked: true)

        #expect(repo.likeCalls == [.init(id: "p9", liked: true)])
        #expect(post.likeCount == 7)
    }
}
