import Testing
import Foundation
@testable import XFeed

@Suite struct FeedRepositoryImplTests {
    let api = FakeFeedAPIClient()
    var sut: FeedRepositoryImpl { FeedRepositoryImpl(api: api) }

    @Test func feedMapsDTOsToEntitiesAndForwardsPaging() async throws {
        api.feedResult = .success(FeedPageDTO(posts: [.fixture()], nextCursor: "9"))

        let page = try await sut.feed(cursor: "10", limit: 7)

        #expect(api.lastFeedArguments?.cursor == "10")
        #expect(api.lastFeedArguments?.limit == 7)
        #expect(page.nextCursor == "9")
        #expect(page.posts == [Post(
            id: "p1",
            author: Author(id: "a1", name: "Maya", handle: "maya", avatarURL: URL(string: "https://picsum.photos/id/2/10/10")),
            text: "hello", imageURL: URL(string: "https://picsum.photos/id/1/10/10"),
            createdAt: Date(timeIntervalSince1970: 500), likeCount: 3, isLikedByMe: true)])
    }

    @Test func missingImageMapsToNil() async throws {
        api.feedResult = .success(FeedPageDTO(posts: [.fixture(image: nil)], nextCursor: nil))
        let page = try await sut.feed(cursor: nil, limit: 10)
        #expect(page.posts.first?.imageURL == nil)
    }

    @Test func createPostSendsTextAndImageURLString() async throws {
        api.createResult = .success(.fixture(id: "new"))
        let post = try await sut.createPost(text: "yo", imageURL: URL(string: "https://picsum.photos/id/5/1/1"))
        #expect(api.lastCreateRequest == CreatePostRequestDTO(text: "yo", imageURL: "https://picsum.photos/id/5/1/1"))
        #expect(post.id == "new")
    }

    @Test func setLikeSendsDesiredStateAndReturnsAuthoritativePost() async throws {
        api.likeResult = .success(.fixture(likes: 9, liked: false))
        let post = try await sut.setLike(postID: "p1", liked: false)
        #expect(api.lastLike?.id == "p1" && api.lastLike?.liked == false)
        #expect(post.likeCount == 9 && !post.isLikedByMe)
    }

    @Test(arguments: [
        (FeedAPIError.offline, FeedError.offline),
        (FeedAPIError.server(status: 503), FeedError.server),
        (FeedAPIError.notFound, FeedError.notFound),
        (FeedAPIError.decoding, FeedError.server),
    ])
    func mapsTransportErrorsToDomainErrors(_ input: FeedAPIError, _ expected: FeedError) async {
        api.feedResult = .failure(input)
        await #expect(throws: expected) { try await sut.feed(cursor: nil, limit: 10) }
    }
}
