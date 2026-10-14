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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CreatePostError.emptyText }
        guard trimmed.count <= Self.maxLength else { throw CreatePostError.tooLong }
        let imageURL = try Self.parseImageURL(imageURLString)
        return try await repository.createPost(text: trimmed, imageURL: imageURL)
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
