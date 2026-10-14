import Foundation

/// Shape of the bundled `seed_posts.json`.
struct SeedData: Decodable, Sendable {
    struct SeedPost: Decodable, Sendable {
        let id: String
        let authorID: String
        let text: String
        let imageURL: String?
        let ageMinutes: Int
        let likeCount: Int
        let isLikedByMe: Bool
    }

    let authors: [AuthorDTO]
    let posts: [SeedPost]

    static let meID = "me"

    /// The fixed current user; falls back to a bare author if the seed file omits it.
    var me: AuthorDTO {
        authors.first { $0.id == Self.meID } ?? AuthorDTO(id: Self.meID, name: "Me", handle: "me", avatarURL: nil)
    }

    static func load(from bundle: Bundle) throws -> SeedData {
        guard let url = bundle.url(forResource: "seed_posts", withExtension: "json") else {
            throw FeedAPIError.notFound
        }
        return try JSONDecoder().decode(SeedData.self, from: Data(contentsOf: url))
    }
}
