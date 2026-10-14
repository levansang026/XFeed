import Foundation

struct Author: Equatable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let handle: String
    let avatarURL: URL?
}

struct Post: Equatable, Sendable, Identifiable {
    let id: String
    let author: Author
    let text: String
    let imageURL: URL?
    let createdAt: Date
    var likeCount: Int
    var isLikedByMe: Bool
}

struct FeedPage: Equatable, Sendable {
    let posts: [Post]
    /// `nil` means the end of the Feed.
    let nextCursor: String?
}

enum FeedError: Error, Equatable, Sendable {
    case offline
    case server
    case notFound

    /// Anything that isn't already a `FeedError` is treated as a server failure.
    init(_ error: Error) { self = error as? FeedError ?? .server }
}
