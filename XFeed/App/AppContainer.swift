import Foundation

/// Composition root. Swapping the backend means replacing `MockFeedAPIClient` here and nothing else.
@MainActor
struct AppContainer {
    let feed: FeedViewModel
    let me: Author
    let mockController: (any MockControlling)?

    static func live() -> AppContainer {
        do {
            let seed = try SeedData.load(from: .main)
            let mock = MockFeedAPIClient(seed: seed)
            return make(api: mock, controller: mock, seed: seed)
        } catch {
            fatalError("Missing or invalid seed_posts.json: \(error)")
        }
    }

    private static func make(api: any FeedAPIClient, controller: (any MockControlling)?, seed: SeedData) -> AppContainer {
        let repository = FeedRepositoryImpl(api: api)
        let feed = FeedViewModel(
            loadFeed: LoadFeed(repository: repository),
            createPost: CreatePost(repository: repository),
            setLike: SetLike(repository: repository))
        let meDTO = seed.authors.first { $0.id == "me" }
        let me = Author(
            id: "me", name: meDTO?.name ?? "Me", handle: meDTO?.handle ?? "me",
            avatarURL: meDTO?.avatarURL.flatMap(URL.init(string:)))
        return AppContainer(feed: feed, me: me, mockController: controller)
    }
}
