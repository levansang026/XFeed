import Foundation

struct AuthorDTO: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let handle: String
    let avatarURL: String?
}

struct PostDTO: Codable, Equatable, Sendable {
    let id: String
    let author: AuthorDTO
    let text: String
    let imageURL: String?
    let createdAt: Date
    let likeCount: Int
    let isLikedByMe: Bool
}

struct FeedPageDTO: Codable, Equatable, Sendable {
    let posts: [PostDTO]
    let nextCursor: String?
}

struct CreatePostRequestDTO: Codable, Equatable, Sendable {
    let text: String
    let imageURL: String?
}
