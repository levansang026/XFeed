import Foundation

struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var base: any RandomNumberGenerator
    init(_ base: some RandomNumberGenerator) { self.base = base }
    mutating func next() -> UInt64 { base.next() }
}

/// In-memory mock backend with latency and random failure. State resets on every launch.
actor MockFeedAPIClient: FeedAPIClient, MockControlling {
    private struct Entry {
        let order: Int
        var post: PostDTO
    }

    private let seed: SeedData
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (Duration) async throws -> Void
    private var random: AnyRandomNumberGenerator
    private var config: MockConfig
    private var forceFailure = false
    private var entries: [Entry] = []
    private var nextOrder = 1

    init(
        seed: SeedData,
        config: MockConfig = .default,
        random: some RandomNumberGenerator & Sendable = SystemRandomNumberGenerator(),
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.seed = seed
        self.config = config
        self.random = AnyRandomNumberGenerator(random)
        self.now = now
        self.sleep = sleep
        self.entries = Self.makeEntries(seed: seed, reference: now())
        self.nextOrder = entries.count + 1
    }

    // MARK: FeedAPIClient

    func fetchFeed(cursor: String?, limit: Int) async throws -> FeedPageDTO {
        try await simulateNetwork()
        let ceiling = cursor.flatMap(Int.init) ?? Int.max
        let candidates = entries.filter { $0.order < ceiling }.sorted { $0.order > $1.order }
        let page = Array(candidates.prefix(limit))
        let hasMore = candidates.count > page.count
        return FeedPageDTO(posts: page.map(\.post), nextCursor: hasMore ? page.last.map { String($0.order) } : nil)
    }

    func createPost(_ request: CreatePostRequestDTO) async throws -> PostDTO {
        try await simulateNetwork()
        let me = seed.authors.first { $0.id == "me" } ?? AuthorDTO(id: "me", name: "Me", handle: "me", avatarURL: nil)
        let post = PostDTO(
            id: "post-\(UUID().uuidString)", author: me, text: request.text, imageURL: request.imageURL,
            createdAt: now(), likeCount: 0, isLikedByMe: false)
        entries.append(Entry(order: nextOrder, post: post))
        nextOrder += 1
        return post
    }

    func setLike(postID: String, liked: Bool) async throws -> PostDTO {
        try await simulateNetwork()
        guard let index = entries.firstIndex(where: { $0.post.id == postID }) else { throw FeedAPIError.notFound }
        let old = entries[index].post
        guard old.isLikedByMe != liked else { return old }
        let updated = PostDTO(
            id: old.id, author: old.author, text: old.text, imageURL: old.imageURL, createdAt: old.createdAt,
            likeCount: old.likeCount + (liked ? 1 : -1), isLikedByMe: liked)
        entries[index].post = updated
        return updated
    }

    // MARK: MockControlling

    func currentConfig() -> MockConfig { config }

    func update(_ config: MockConfig) { self.config = config }

    func forceNextRequestToFail() { forceFailure = true }

    func resetToSeedData() {
        forceFailure = false
        entries = Self.makeEntries(seed: seed, reference: now())
        nextOrder = entries.count + 1
    }

    // MARK: Internals

    private static func makeEntries(seed: SeedData, reference: Date) -> [Entry] {
        let authors = Dictionary(uniqueKeysWithValues: seed.authors.map { ($0.id, $0) })
        let newestFirst = seed.posts.sorted { $0.ageMinutes < $1.ageMinutes }
        return newestFirst.enumerated().compactMap { offset, item in
            guard let author = authors[item.authorID] else { return nil }
            let post = PostDTO(
                id: item.id, author: author, text: item.text, imageURL: item.imageURL,
                createdAt: reference.addingTimeInterval(-Double(item.ageMinutes) * 60),
                likeCount: item.likeCount, isLikedByMe: item.isLikedByMe)
            return Entry(order: newestFirst.count - offset, post: post)
        }
    }

    private func simulateNetwork() async throws {
        let latency = Double.random(in: config.minLatency...max(config.minLatency, config.maxLatency), using: &random)
        try await sleep(.seconds(latency))
        if forceFailure {
            forceFailure = false
            throw randomFailure()
        }
        if Double.random(in: 0..<1, using: &random) < config.failureRate {
            throw randomFailure()
        }
    }

    private func randomFailure() -> FeedAPIError {
        Bool.random(using: &random) ? .offline : .server(status: 500)
    }
}
