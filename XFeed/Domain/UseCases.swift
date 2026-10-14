import Foundation

enum CreatePostError: Error, Equatable, Sendable {
    case emptyText
    case tooLong
    case invalidImageURL
}

struct CreatePost: Sendable {
    static let maxLength = 280

    let repository: any FeedRepository

    func callAsFunction(text: String, imageURLString: String?) async throws -> Post {
        let input = try Self.validate(text: text, imageURLString: imageURLString)
        return try await repository.createPost(text: input.text, imageURL: input.imageURL)
    }

    /// Synchronous validation so callers can reject input before showing a Pending Post.
    static func validate(text: String, imageURLString: String?) throws -> (text: String, imageURL: URL?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CreatePostError.emptyText }
        guard trimmed.count <= maxLength else { throw CreatePostError.tooLong }
        return (trimmed, try parseImageURL(imageURLString))
    }

    /// Synchronous validation so the Composer can validate as the user types.
    static func parseImageURL(_ string: String?) throws -> URL? {
        let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        let pattern = /^https?:\/\/[^\s\/$.?#]+\.[^\s]+$/
        guard trimmed.wholeMatch(of: pattern) != nil, let url = URL(string: trimmed) else {
            throw CreatePostError.invalidImageURL
        }
        return url
    }
}

struct LoadFeed: Sendable {
    static let pageSize = 10
    let repository: any FeedRepository

    func callAsFunction(cursor: String?, limit: Int = pageSize) async throws -> FeedPage {
        try await repository.feed(cursor: cursor, limit: limit)
    }
}

struct SetLike: Sendable {
    let repository: any FeedRepository

    func callAsFunction(postID: String, liked: Bool) async throws -> Post {
        try await repository.setLike(postID: postID, liked: liked)
    }
}
