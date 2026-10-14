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

    static func load(from bundle: Bundle) throws -> SeedData {
        guard let url = bundle.url(forResource: "seed_posts", withExtension: "json") else {
            throw FeedAPIError.notFound
        }
        return try JSONDecoder().decode(SeedData.self, from: Data(contentsOf: url))
    }
}
