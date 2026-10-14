import Foundation
@testable import XFeed

/// Scripted `FeedAPIClient` for repository tests.
final class FakeFeedAPIClient: FeedAPIClient, @unchecked Sendable {
    var feedResult: Result<FeedPageDTO, Error> = .success(FeedPageDTO(posts: [], nextCursor: nil))
    var createResult: Result<PostDTO, Error> = .failure(FeedAPIError.offline)
    var likeResult: Result<PostDTO, Error> = .failure(FeedAPIError.offline)
    private(set) var lastFeedArguments: (cursor: String?, limit: Int)?
    private(set) var lastCreateRequest: CreatePostRequestDTO?
    private(set) var lastLike: (id: String, liked: Bool)?

    func fetchFeed(cursor: String?, limit: Int) async throws -> FeedPageDTO {
        lastFeedArguments = (cursor, limit)
        return try feedResult.get()
    }
    func createPost(_ request: CreatePostRequestDTO) async throws -> PostDTO {
        lastCreateRequest = request
        return try createResult.get()
    }
    func setLike(postID: String, liked: Bool) async throws -> PostDTO {
        lastLike = (postID, liked)
        return try likeResult.get()
    }
}

extension PostDTO {
    static func fixture(id: String = "p1", image: String? = "https://picsum.photos/id/1/10/10", likes: Int = 3, liked: Bool = true) -> PostDTO {
        PostDTO(
            id: id, author: AuthorDTO(id: "a1", name: "Maya", handle: "maya", avatarURL: "https://picsum.photos/id/2/10/10"),
            text: "hello", imageURL: image, createdAt: Date(timeIntervalSince1970: 500), likeCount: likes, isLikedByMe: liked)
    }
}
