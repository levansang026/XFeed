import Foundation
import Testing
@testable import XFeed

/// Test double for `FeedRepository`. Override the handlers to script results or suspend a call.
final class FakeFeedRepository: FeedRepository, @unchecked Sendable {
    struct Created: Equatable { let text: String; let imageURL: URL? }
    struct LikeCall: Equatable { let id: String; let liked: Bool }

    var onFeed: @Sendable (String?, Int) async throws -> FeedPage = { _, _ in FeedPage(posts: [], nextCursor: nil) }
    var onCreate: @Sendable (String, URL?) async throws -> Post = { text, url in
        TestData.post(id: "new", text: text, imageURL: url)
    }
    var onLike: @Sendable (String, Bool) async throws -> Post = { id, liked in
        TestData.post(id: id, likeCount: liked ? 1 : 0, isLiked: liked)
    }

    private let lock = NSLock()
    private var _created: [Created] = []
    private var _likes: [LikeCall] = []
    private var _cursors: [String?] = []
    var createdPosts: [Created] { lock.withLock { _created } }
    var likeCalls: [LikeCall] { lock.withLock { _likes } }
    var feedCursors: [String?] { lock.withLock { _cursors } }

    func feed(cursor: String?, limit: Int) async throws -> FeedPage {
        lock.withLock { _cursors.append(cursor) }
        return try await onFeed(cursor, limit)
    }

    func createPost(text: String, imageURL: URL?) async throws -> Post {
        lock.withLock { _created.append(Created(text: text, imageURL: imageURL)) }
        return try await onCreate(text, imageURL)
    }

    func setLike(postID: String, liked: Bool) async throws -> Post {
        lock.withLock { _likes.append(LikeCall(id: postID, liked: liked)) }
        return try await onLike(postID, liked)
    }
}

/// A call that stays suspended until the test completes it.
final class Suspended<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?
    private var early: Result<T, Error>?

    func wait() async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            lock.lock()
            if let early { lock.unlock(); cont.resume(with: early) } else { continuation = cont; lock.unlock() }
        }
    }

    func complete(_ result: Result<T, Error>) {
        lock.lock()
        if let continuation { self.continuation = nil; lock.unlock(); continuation.resume(with: result) }
        else { early = result; lock.unlock() }
    }
}

/// Yields until `condition` holds, so tests never sleep for a fixed time.
@MainActor
func waitUntil(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
    for _ in 0..<2_000 where !condition() { await Task.yield() }
    #expect(condition(), "condition never became true", sourceLocation: sourceLocation)
}
