import Foundation
import Observation

enum LoadPhase: Equatable {
    case idle, loading, loaded, failed(FeedError)
}

enum LoadMoreState: Equatable {
    case idle, loading, failed, ended
}

struct PendingPost: Identifiable, Equatable {
    enum Status: Equatable { case sending, failed(FeedError) }

    let id: UUID
    let text: String
    let imageURL: URL?
    var status: Status
}

@MainActor
@Observable
final class FeedViewModel {
    private(set) var posts: [Post] = []
    private(set) var pendingPosts: [PendingPost] = []
    private(set) var phase: LoadPhase = .idle
    private(set) var loadMore: LoadMoreState = .idle
    private(set) var isRefreshing = false
    private(set) var errorMessage: String?

    private struct LikeSync {
        var confirmed: Post
        var desired: Bool
        var revision = 0
    }

    private static let prefetchDistance = 5

    @ObservationIgnored private let loadFeed: LoadFeed
    @ObservationIgnored private let createPost: CreatePost
    @ObservationIgnored private let setLike: SetLike
    @ObservationIgnored private let likeDebounce: Duration
    @ObservationIgnored private var nextCursor: String?
    @ObservationIgnored private var loadEpoch = 0
    /// Only recorded while a load is running (see `isLoading`): server state that is newer than that load's payload.
    @ObservationIgnored private var confirmedDuringLoad: [String: Post] = [:]
    @ObservationIgnored private var createdDuringLoad: [Post] = []
    @ObservationIgnored private var likeSyncs: [String: LikeSync] = [:]
    @ObservationIgnored private var likeTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var createTasks: [UUID: Task<Void, Never>] = [:]

    init(loadFeed: LoadFeed, createPost: CreatePost, setLike: SetLike, likeDebounce: Duration = .milliseconds(300)) {
        self.loadFeed = loadFeed
        self.createPost = createPost
        self.setLike = setLike
        self.likeDebounce = likeDebounce
    }

    func dismissError() { errorMessage = nil }

    // MARK: Loading

    func loadInitial() async {
        guard phase == .idle || isFailed else { return }
        await load(isUserRefresh: false)
    }

    func refresh() async {
        await load(isUserRefresh: true)
    }

    func loadMoreIfNeeded(currentPostID: String) async {
        guard phase == .loaded, !isRefreshing, loadMore == .idle,
              let index = posts.firstIndex(where: { $0.id == currentPostID }),
              index >= posts.count - Self.prefetchDistance else { return }
        await loadNextPage()
    }

    func retryLoadMore() async {
        guard !isRefreshing, loadMore == .failed else { return }
        await loadNextPage()
    }

    private var isLoading: Bool { isRefreshing || loadMore == .loading }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    private func load(isUserRefresh: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        loadEpoch += 1
        let token = loadEpoch
        confirmedDuringLoad = [:]
        createdDuringLoad = []
        if loadMore == .loading { loadMore = .idle }   // the in-flight load-more is now stale and discards itself
        if posts.isEmpty { phase = .loading }
        defer {
            isRefreshing = false
            confirmedDuringLoad = [:]
            createdDuringLoad = []
        }
        do {
            let page = try await loadFeed(cursor: nil)
            guard token == loadEpoch else { return }
            let serverIDs = Set(page.posts.map(\.id))
            // Posts created during this load are newer than the page; keep them on top, newest first, in their
            // current form (a Like may have been applied since they were created).
            let survivors = createdDuringLoad.reversed()
                .filter { !serverIDs.contains($0.id) }
                .map { created in posts.first { $0.id == created.id } ?? created }
            posts = survivors + reconcile(page.posts)
            apply(page)
            phase = .loaded
        } catch {
            guard token == loadEpoch else { return }
            if posts.isEmpty {
                phase = .failed(FeedError(error))
            } else {
                phase = .loaded
                errorMessage = "Couldn't refresh. Try again."
            }
        }
    }

    private func loadNextPage() async {
        loadMore = .loading
        let token = loadEpoch
        // A refresh that starts meanwhile bumps the epoch and owns the bookkeeping from then on.
        defer { if token == loadEpoch { confirmedDuringLoad = [:] } }
        do {
            let page = try await loadFeed(cursor: nextCursor)
            guard token == loadEpoch else { return }
            let known = Set(posts.map(\.id))
            posts += reconcile(page.posts.filter { !known.contains($0.id) })
            apply(page)
        } catch {
            guard token == loadEpoch else { return }
            loadMore = .failed
        }
    }

    private func apply(_ page: FeedPage) {
        nextCursor = page.nextCursor
        loadMore = page.nextCursor == nil ? .ended : .idle
    }

    /// Server data never overwrites a Post whose Like is still syncing, and never overrides a confirmation that
    /// arrived after the load began. Otherwise it is the newest known server state and the rollback baseline.
    private func reconcile(_ server: [Post]) -> [Post] {
        server.map { post in
            let confirmedLater = confirmedDuringLoad[post.id]
            if var sync = likeSyncs[post.id] {
                if confirmedLater == nil { sync.confirmed = post }
                likeSyncs[post.id] = sync
                return posts.first { $0.id == post.id } ?? confirmedLater ?? post
            }
            return confirmedLater ?? post
        }
    }

    // MARK: Likes

    func toggleLike(postID: String) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let before = posts[index]
        var sync = likeSyncs[postID] ?? LikeSync(confirmed: before, desired: before.isLikedByMe)
        sync.desired = !before.isLikedByMe
        sync.revision += 1
        likeSyncs[postID] = sync

        posts[index].isLikedByMe = sync.desired
        posts[index].likeCount += sync.desired ? 1 : -1

        if likeTasks[postID] == nil {
            likeTasks[postID] = Task { await runLikeSync(postID: postID) }
        }
    }

    func settleLikes() async {
        while let task = likeTasks.values.first { await task.value }
    }

    private func runLikeSync(postID: String) async {
        defer { likeTasks[postID] = nil }
        while let sync = likeSyncs[postID] {
            try? await Task.sleep(for: likeDebounce)
            guard let current = likeSyncs[postID] else { return }
            if current.revision != sync.revision { continue }
            if current.desired == current.confirmed.isLikedByMe {
                likeSyncs[postID] = nil
                return
            }
            do {
                let confirmed = try await setLike(postID: postID, liked: current.desired)
                guard var latest = likeSyncs[postID] else { return }
                latest.confirmed = confirmed
                if isLoading { confirmedDuringLoad[postID] = confirmed }
                if latest.desired == confirmed.isLikedByMe {
                    likeSyncs[postID] = nil
                    replace(confirmed)
                    return
                }
                likeSyncs[postID] = latest
                showOptimistic(desired: latest.desired, over: confirmed)
            } catch {
                let baseline = likeSyncs[postID]?.confirmed
                likeSyncs[postID] = nil
                if let baseline { replace(baseline) }
                errorMessage = "Couldn't update your like. Try again."
                return
            }
        }
    }

    private func replace(_ post: Post) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index] = post
    }

    private func showOptimistic(desired: Bool, over confirmed: Post) {
        var shown = confirmed
        shown.isLikedByMe = desired
        shown.likeCount += desired == confirmed.isLikedByMe ? 0 : (desired ? 1 : -1)
        replace(shown)
    }

    // MARK: Creating posts

    func submit(text: String, imageURLString: String?) throws {
        let input = try CreatePost.validate(text: text, imageURLString: imageURLString)
        let pending = PendingPost(id: UUID(), text: input.text, imageURL: input.imageURL, status: .sending)
        pendingPosts.insert(pending, at: 0)
        send(pending)
    }

    func retry(pendingID: UUID) {
        guard let index = pendingPosts.firstIndex(where: { $0.id == pendingID }),
              pendingPosts[index].status != .sending else { return }
        pendingPosts[index].status = .sending
        send(pendingPosts[index])
    }

    func discard(pendingID: UUID) {
        pendingPosts.removeAll { $0.id == pendingID }
    }

    func settleCreates() async {
        while let task = createTasks.values.first { await task.value }
    }

    private func send(_ pending: PendingPost) {
        let id = pending.id
        createTasks[id] = Task {
            defer { createTasks[id] = nil }
            do {
                let post = try await createPost(
                    text: pending.text, imageURLString: pending.imageURL?.absoluteString)
                pendingPosts.removeAll { $0.id == id }
                if isLoading { createdDuringLoad.append(post) }
                if !posts.contains(where: { $0.id == post.id }) { posts.insert(post, at: 0) }
            } catch {
                guard let index = pendingPosts.firstIndex(where: { $0.id == id }) else { return }
                pendingPosts[index].status = .failed(FeedError(error))
            }
        }
    }
}
