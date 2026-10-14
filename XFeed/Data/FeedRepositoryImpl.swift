import Foundation

struct FeedRepositoryImpl: FeedRepository {
    let api: any FeedAPIClient

    func feed(cursor: String?, limit: Int) async throws -> FeedPage {
        try await mapErrors {
            let dto = try await api.fetchFeed(cursor: cursor, limit: limit)
            return FeedPage(posts: dto.posts.map(Self.post(from:)), nextCursor: dto.nextCursor)
        }
    }

    func createPost(text: String, imageURL: URL?) async throws -> Post {
        try await mapErrors {
            Self.post(from: try await api.createPost(CreatePostRequestDTO(text: text, imageURL: imageURL?.absoluteString)))
        }
    }

    func setLike(postID: String, liked: Bool) async throws -> Post {
        try await mapErrors { Self.post(from: try await api.setLike(postID: postID, liked: liked)) }
    }

    private func mapErrors<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let error as FeedAPIError {
            switch error {
            case .offline: throw FeedError.offline
            case .notFound: throw FeedError.notFound
            case .server, .decoding: throw FeedError.server
            }
        }
    }

    private static func post(from dto: PostDTO) -> Post {
        Post(
            id: dto.id,
            author: Author(
                id: dto.author.id, name: dto.author.name, handle: dto.author.handle,
                avatarURL: dto.author.avatarURL.flatMap(URL.init(string:))),
            text: dto.text, imageURL: dto.imageURL.flatMap(URL.init(string:)),
            createdAt: dto.createdAt, likeCount: dto.likeCount, isLikedByMe: dto.isLikedByMe)
    }
}
