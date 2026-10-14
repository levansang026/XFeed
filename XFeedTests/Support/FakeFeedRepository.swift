import Foundation
@testable import XFeed

/// Test double for `FeedRepository` with scripted results.
final class FakeFeedRepository: FeedRepository, @unchecked Sendable {
    struct Created: Equatable { let text: String; let imageURL: URL? }

    private let lock = NSLock()
    private var _created: [Created] = []
    var createdPosts: [Created] { lock.withLock { _created } }

    func feed(cursor: String?, limit: Int) async throws -> FeedPage {
        FeedPage(posts: [], nextCursor: nil)
    }

    func createPost(text: String, imageURL: URL?) async throws -> Post {
        lock.withLock { _created.append(Created(text: text, imageURL: imageURL)) }
        return TestData.post(id: "new", text: text, imageURL: imageURL)
    }

    func setLike(postID: String, liked: Bool) async throws -> Post {
        TestData.post(id: postID, isLiked: liked)
    }
}
