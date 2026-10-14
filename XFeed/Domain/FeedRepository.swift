import Foundation

protocol FeedRepository: Sendable {
    func feed(cursor: String?, limit: Int) async throws -> FeedPage
    func createPost(text: String, imageURL: URL?) async throws -> Post
    /// Idempotent: sets the desired liked state and returns the server's authoritative Post.
    func setLike(postID: String, liked: Bool) async throws -> Post
}
