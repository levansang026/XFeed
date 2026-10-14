import Foundation

/// Transport-level failures. `FeedRepositoryImpl` maps these to Domain errors.
enum FeedAPIError: Error, Equatable, Sendable {
    case offline
    case server(status: Int)
    case notFound
    case decoding
}

/// The backend contract. `MockFeedAPIClient` implements it today; a URLSession client can replace it later.
protocol FeedAPIClient: Sendable {
    func fetchFeed(cursor: String?, limit: Int) async throws -> FeedPageDTO
    func createPost(_ request: CreatePostRequestDTO) async throws -> PostDTO
    func setLike(postID: String, liked: Bool) async throws -> PostDTO
}
