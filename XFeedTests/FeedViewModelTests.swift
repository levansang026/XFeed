import Testing
import Foundation
@testable import XFeed

@MainActor
@Suite struct FeedViewModelTests {
    let repo = FakeFeedRepository()

    func makeSUT() -> FeedViewModel {
        FeedViewModel(
            loadFeed: LoadFeed(repository: repo), createPost: CreatePost(repository: repo),
            setLike: SetLike(repository: repo), likeDebounce: .zero)
    }

    func loadedSUT(pages: [String?: FeedPage] = [nil: TestData.page(1...10, next: "c1")]) async -> FeedViewModel {
        repo.onFeed = { cursor, _ in pages[cursor] ?? FeedPage(posts: [], nextCursor: nil) }
        let sut = makeSUT()
        await sut.loadInitial()
        return sut
    }

    // MARK: Loading and pagination

    @Test func initialLoadShowsFirstPage() async {
        let sut = await loadedSUT()
        #expect(sut.phase == .loaded)
        #expect(sut.posts.map(\.id) == (1...10).map { "p\($0)" })
        #expect(sut.loadMore == .idle)
    }

    @Test func initialLoadFailureCanBeRetried() async {
        repo.onFeed = { _, _ in throw FeedError.offline }
        let sut = makeSUT()
        await sut.loadInitial()
        #expect(sut.phase == .failed(.offline))

        repo.onFeed = { _, _ in TestData.page(1...3, next: nil) }
        await sut.loadInitial()
        #expect(sut.phase == .loaded)
        #expect(sut.posts.count == 3)
    }

    @Test func reachingNearTheEndLoadsNextPageAndStopsAtEndOfFeed() async {
        let sut = await loadedSUT(pages: [nil: TestData.page(1...10, next: "c1"), "c1": TestData.page(11...12, next: nil)])

        await sut.loadMoreIfNeeded(currentPostID: "p8")

        #expect(sut.posts.count == 12)
        #expect(sut.loadMore == .ended)
        #expect(repo.feedCursors == [nil, "c1"])
    }

    @Test func rowsFarFromTheEndDoNotLoadMore() async {
        let sut = await loadedSUT()
        await sut.loadMoreIfNeeded(currentPostID: "p5")
        #expect(repo.feedCursors == [nil])
    }

    @Test func onlyOneLoadMoreRunsAtATime() async {
        let sut = await loadedSUT()
        let gate = Suspended<FeedPage>()
        repo.onFeed = { _, _ in try await gate.wait() }

        async let first: Void = sut.loadMoreIfNeeded(currentPostID: "p10")
        await waitUntil { sut.loadMore == .loading }
        await sut.loadMoreIfNeeded(currentPostID: "p10")
        gate.complete(.success(TestData.page(11...12, next: nil)))
        await first

        #expect(repo.feedCursors == [nil, "c1"])
    }

    @Test func loadMoreFailureShowsRetryAndRetrySucceeds() async {
        let sut = await loadedSUT()
        repo.onFeed = { _, _ in throw FeedError.server }
        await sut.loadMoreIfNeeded(currentPostID: "p10")
        #expect(sut.loadMore == .failed)
        #expect(sut.posts.count == 10)

        repo.onFeed = { _, _ in TestData.page(11...12, next: nil) }
        await sut.retryLoadMore()
        #expect(sut.posts.count == 12)
        #expect(sut.loadMore == .ended)
    }

    @Test func nextPageSkipsPostsAlreadyInTheList() async {
        let sut = await loadedSUT()
        repo.onFeed = { _, _ in TestData.page(9...12, next: nil) }
        await sut.loadMoreIfNeeded(currentPostID: "p10")
        #expect(sut.posts.map(\.id) == (1...12).map { "p\($0)" })
    }

    @Test func refreshReplacesListWithFirstPage() async {
        let sut = await loadedSUT(pages: [nil: TestData.page(1...10, next: "c1"), "c1": TestData.page(11...12, next: nil)])
        await sut.loadMoreIfNeeded(currentPostID: "p10")
        #expect(sut.loadMore == .ended)

        repo.onFeed = { _, _ in TestData.page(100...102, next: "x") }
        await sut.refresh()

        #expect(sut.posts.map(\.id) == ["p100", "p101", "p102"])
        #expect(sut.loadMore == .idle)
    }

    @Test func refreshFailureKeepsCurrentList() async {
        let sut = await loadedSUT()
        repo.onFeed = { _, _ in throw FeedError.offline }
        await sut.refresh()
        #expect(sut.posts.count == 10)
        #expect(sut.phase == .loaded)
        #expect(sut.errorMessage != nil)
    }

    @Test func refreshDiscardsAnInFlightLoadMore() async {
        let sut = await loadedSUT()
        let slowPage = Suspended<FeedPage>()
        repo.onFeed = { cursor, _ in
            cursor == "c1" ? try await slowPage.wait() : TestData.page(100...101, next: "c9")
        }

        async let loadMore: Void = sut.loadMoreIfNeeded(currentPostID: "p10")
        await waitUntil { sut.loadMore == .loading }
        await sut.refresh()
        slowPage.complete(.success(TestData.page(11...12, next: nil)))
        await loadMore

        #expect(sut.posts.map(\.id) == ["p100", "p101"])
        #expect(sut.loadMore == .idle)
    }

    // MARK: Refresh racing with other operations

    @Test func failedRefreshDoesNotLeaveAnInFlightLoadMoreSpinning() async {
        let sut = await loadedSUT()
        let slowPage = Suspended<FeedPage>()
        repo.onFeed = { cursor, _ in
            if cursor == "c1" { return try await slowPage.wait() }
            throw FeedError.offline
        }

        async let loadMore: Void = sut.loadMoreIfNeeded(currentPostID: "p10")
        await waitUntil { sut.loadMore == .loading }
        await sut.refresh()
        #expect(sut.loadMore == .idle)
        slowPage.complete(.success(TestData.page(11...12, next: nil)))
        await loadMore

        #expect(sut.loadMore == .idle)
        #expect(sut.posts.count == 10)
    }

    @Test func loadMoreIsIgnoredWhileRefreshing() async {
        let sut = await loadedSUT()
        let refreshPage = Suspended<FeedPage>()
        repo.onFeed = { _, _ in try await refreshPage.wait() }

        async let refresh: Void = sut.refresh()
        await waitUntil { sut.isRefreshing }
        await sut.loadMoreIfNeeded(currentPostID: "p10")
        #expect(repo.feedCursors == [nil, nil])

        refreshPage.complete(.success(TestData.page(100...101, next: "c9")))
        await refresh
        #expect(sut.posts.map(\.id) == ["p100", "p101"])
    }

    @Test func postConfirmedDuringARefreshSurvivesIt() async throws {
        let sut = await loadedSUT()
        let create = Suspended<Post>()
        let refreshPage = Suspended<FeedPage>()
        repo.onCreate = { _, _ in try await create.wait() }
        repo.onFeed = { _, _ in try await refreshPage.wait() }
        try sut.submit(text: "hi", imageURLString: nil)

        async let refresh: Void = sut.refresh()
        await waitUntil { sut.isRefreshing }
        create.complete(.success(TestData.post(id: "srv-1", text: "hi")))
        await sut.settleCreates()
        refreshPage.complete(.success(TestData.page(1...10, next: "c1")))   // fetched before the create
        await refresh

        #expect(sut.posts.first?.id == "srv-1")
        #expect(sut.posts.count == 11)
    }

    @Test func likeConfirmedDuringARefreshIsNotRevertedByStaleRefreshData() async {
        let sut = await loadedSUT()
        let refreshPage = Suspended<FeedPage>()
        repo.onFeed = { _, _ in try await refreshPage.wait() }
        repo.onLike = { id, liked in TestData.post(id: id, likeCount: 1, isLiked: liked) }

        async let refresh: Void = sut.refresh()
        await waitUntil { sut.isRefreshing }
        sut.toggleLike(postID: "p1")
        await sut.settleLikes()
        refreshPage.complete(.success(TestData.page(1...10, next: "c1")))   // p1 still unliked here
        await refresh

        #expect(sut.posts[0].isLikedByMe && sut.posts[0].likeCount == 1)
    }

    @Test func staleRefreshDataDoesNotLowerTheRollbackBaseline() async {
        let sut = await loadedSUT()
        let firstLike = Suspended<Post>()
        let secondLike = Suspended<Post>()
        let refreshPage = Suspended<FeedPage>()
        nonisolated(unsafe) var calls = 0
        repo.onLike = { _, _ in
            calls += 1
            return try await (calls == 1 ? firstLike : secondLike).wait()
        }

        sut.toggleLike(postID: "p1")
        await waitUntil { repo.likeCalls.count == 1 }
        repo.onFeed = { _, _ in try await refreshPage.wait() }
        async let refresh: Void = sut.refresh()
        await waitUntil { sut.isRefreshing }
        sut.toggleLike(postID: "p1")                       // wants unliked again
        firstLike.complete(.success(TestData.post(id: "p1", likeCount: 1, isLiked: true)))
        await waitUntil { repo.likeCalls.count == 2 }
        refreshPage.complete(.success(TestData.page(1...10, next: "c1")))   // stale: p1 unliked, 0
        await refresh
        secondLike.complete(.failure(FeedError.server))
        await sut.settleLikes()

        #expect(sut.posts[0].isLikedByMe && sut.posts[0].likeCount == 1)
    }

    @Test(arguments: [true, false])
    func postCreatedAndLikedDuringARefreshKeepsItsLike(likeSettlesBeforeRefreshEnds: Bool) async throws {
        let sut = await loadedSUT()
        let create = Suspended<Post>()
        let refreshPage = Suspended<FeedPage>()
        repo.onCreate = { _, _ in try await create.wait() }
        repo.onFeed = { _, _ in try await refreshPage.wait() }
        repo.onLike = { id, liked in TestData.post(id: id, likeCount: 1, isLiked: liked) }
        try sut.submit(text: "hi", imageURLString: nil)

        async let refresh: Void = sut.refresh()
        await waitUntil { sut.isRefreshing }
        create.complete(.success(TestData.post(id: "srv-1", text: "hi")))
        await sut.settleCreates()
        sut.toggleLike(postID: "srv-1")
        if likeSettlesBeforeRefreshEnds { await sut.settleLikes() }
        refreshPage.complete(.success(TestData.page(1...10, next: "c1")))   // fetched before the create
        await refresh
        await sut.settleLikes()

        #expect(sut.posts.first?.id == "srv-1")
        #expect(sut.posts.first?.isLikedByMe == true && sut.posts.first?.likeCount == 1)
    }

    @Test func postsCreatedDuringARefreshKeepNewestFirstOrder() async throws {
        let sut = await loadedSUT()
        let first = Suspended<Post>()
        let second = Suspended<Post>()
        let refreshPage = Suspended<FeedPage>()
        repo.onCreate = { text, _ in try await (text == "first" ? first : second).wait() }
        repo.onFeed = { _, _ in try await refreshPage.wait() }
        try sut.submit(text: "first", imageURLString: nil)
        try sut.submit(text: "second", imageURLString: nil)

        async let refresh: Void = sut.refresh()
        await waitUntil { sut.isRefreshing }
        first.complete(.success(TestData.post(id: "srv-1", text: "first")))
        await waitUntil { sut.posts.first?.id == "srv-1" }
        second.complete(.success(TestData.post(id: "srv-2", text: "second")))
        await waitUntil { sut.posts.first?.id == "srv-2" }
        refreshPage.complete(.success(TestData.page(1...10, next: "c1")))
        await refresh

        #expect(sut.posts.prefix(2).map(\.id) == ["srv-2", "srv-1"])
    }

    @Test func raceBookkeepingFromEarlierLoadsDoesNotLeakIntoALaterRefresh() async throws {
        let sut = await loadedSUT()
        repo.onCreate = { _, _ in TestData.post(id: "srv-1", text: "hi") }
        try sut.submit(text: "hi", imageURLString: nil)       // confirmed while nothing is loading
        await sut.settleCreates()

        repo.onFeed = { _, _ in TestData.page(1...10, next: "c1") }   // server does not know srv-1
        await sut.refresh()

        #expect(sut.posts.map(\.id) == (1...10).map { "p\($0)" })
    }

    // MARK: Likes

    @Test func likeUpdatesInstantlyThenAdoptsServerValue() async {
        let sut = await loadedSUT()
        repo.onLike = { id, liked in TestData.post(id: id, likeCount: 42, isLiked: liked) }

        sut.toggleLike(postID: "p1")
        #expect(sut.posts[0].isLikedByMe && sut.posts[0].likeCount == 1)

        await sut.settleLikes()
        #expect(sut.posts[0].likeCount == 42 && sut.posts[0].isLikedByMe)
        #expect(repo.likeCalls == [.init(id: "p1", liked: true)])
    }

    @Test func failedLikeRollsBackToLastConfirmedState() async {
        let sut = await loadedSUT()
        repo.onLike = { _, _ in throw FeedError.offline }

        sut.toggleLike(postID: "p1")
        await sut.settleLikes()

        #expect(!sut.posts[0].isLikedByMe && sut.posts[0].likeCount == 0)
        #expect(sut.errorMessage != nil)
    }

    @Test func rapidTapsAreDebouncedToTheLatestDesiredState() async {
        let sut = await loadedSUT()
        sut.toggleLike(postID: "p1")
        sut.toggleLike(postID: "p1")
        sut.toggleLike(postID: "p1")
        await sut.settleLikes()
        #expect(repo.likeCalls == [.init(id: "p1", liked: true)])
        #expect(sut.posts[0].isLikedByMe)
    }

    @Test func tappingBackToTheConfirmedStateSendsNothing() async {
        let sut = await loadedSUT()
        sut.toggleLike(postID: "p1")
        sut.toggleLike(postID: "p1")
        await sut.settleLikes()
        #expect(repo.likeCalls.isEmpty)
        #expect(!sut.posts[0].isLikedByMe && sut.posts[0].likeCount == 0)
    }

    @Test func tapDuringInFlightRequestSendsLatestStateAfterwards() async {
        let sut = await loadedSUT()
        let first = Suspended<Post>()
        nonisolated(unsafe) var calls = 0
        repo.onLike = { id, liked in
            calls += 1
            if calls == 1 { return try await first.wait() }
            return TestData.post(id: id, likeCount: 0, isLiked: liked)
        }

        sut.toggleLike(postID: "p1")
        await waitUntil { repo.likeCalls.count == 1 }
        sut.toggleLike(postID: "p1")
        #expect(!sut.posts[0].isLikedByMe)

        first.complete(.success(TestData.post(id: "p1", likeCount: 1, isLiked: true)))
        await sut.settleLikes()

        #expect(repo.likeCalls == [.init(id: "p1", liked: true), .init(id: "p1", liked: false)])
        #expect(!sut.posts[0].isLikedByMe && sut.posts[0].likeCount == 0)
    }

    @Test func failureAfterAConfirmedLikeRollsBackToThatConfirmedState() async {
        let sut = await loadedSUT()
        let first = Suspended<Post>()
        nonisolated(unsafe) var calls = 0
        repo.onLike = { id, liked in
            calls += 1
            if calls == 1 { return try await first.wait() }
            throw FeedError.server
        }

        sut.toggleLike(postID: "p1")
        await waitUntil { repo.likeCalls.count == 1 }
        sut.toggleLike(postID: "p1")
        first.complete(.success(TestData.post(id: "p1", likeCount: 1, isLiked: true)))
        await sut.settleLikes()

        #expect(sut.posts[0].isLikedByMe && sut.posts[0].likeCount == 1)
    }

    @Test func refreshWhileLikeInFlightKeepsTheLocalLikedState() async {
        let sut = await loadedSUT()
        let like = Suspended<Post>()
        repo.onLike = { _, _ in try await like.wait() }

        sut.toggleLike(postID: "p1")
        await waitUntil { repo.likeCalls.count == 1 }
        repo.onFeed = { _, _ in TestData.page(1...10, next: nil) }   // stale: p1 not liked
        await sut.refresh()
        #expect(sut.posts[0].isLikedByMe)

        like.complete(.success(TestData.post(id: "p1", likeCount: 1, isLiked: true)))
        await sut.settleLikes()
        #expect(sut.posts[0].isLikedByMe && sut.posts[0].likeCount == 1)
    }

    // MARK: Creating posts

    @Test func submittedPostAppearsAtTopAsSendingThenBecomesAnOrdinaryPost() async throws {
        let sut = await loadedSUT()
        let server = Suspended<Post>()
        repo.onCreate = { _, _ in try await server.wait() }

        try sut.submit(text: " hi ", imageURLString: nil)
        #expect(sut.pendingPosts.map(\.text) == ["hi"])
        #expect(sut.pendingPosts.first?.status == .sending)

        server.complete(.success(TestData.post(id: "srv-1", text: "hi")))
        await sut.settleCreates()

        #expect(sut.pendingPosts.isEmpty)
        #expect(sut.posts.first?.id == "srv-1")
        #expect(sut.posts.count == 11)
    }

    @Test func failedCreateStaysAsFailedPendingPostAndRetrySucceeds() async throws {
        let sut = await loadedSUT()
        repo.onCreate = { _, _ in throw FeedError.offline }
        try sut.submit(text: "hi", imageURLString: nil)
        await sut.settleCreates()
        #expect(sut.pendingPosts.first?.status == .failed(.offline))
        #expect(sut.posts.count == 10)

        repo.onCreate = { text, _ in TestData.post(id: "srv-1", text: text) }
        sut.retry(pendingID: sut.pendingPosts[0].id)
        #expect(sut.pendingPosts.first?.status == .sending)
        await sut.settleCreates()
        #expect(sut.pendingPosts.isEmpty)
        #expect(sut.posts.first?.id == "srv-1")
    }

    @Test func discardRemovesAFailedPendingPost() async throws {
        let sut = await loadedSUT()
        repo.onCreate = { _, _ in throw FeedError.server }
        try sut.submit(text: "hi", imageURLString: nil)
        await sut.settleCreates()

        sut.discard(pendingID: sut.pendingPosts[0].id)
        #expect(sut.pendingPosts.isEmpty)
    }

    @Test func invalidInputIsRejectedWithoutCreatingAPendingPost() async {
        let sut = await loadedSUT()
        #expect(throws: CreatePostError.emptyText) { try sut.submit(text: "  ", imageURLString: nil) }
        #expect(throws: CreatePostError.invalidImageURL) { try sut.submit(text: "x", imageURLString: "nope") }
        #expect(sut.pendingPosts.isEmpty)
    }

    @Test func confirmedPostIsNotDuplicatedWhenARefreshAlreadyReturnedIt() async throws {
        let sut = await loadedSUT()
        let server = Suspended<Post>()
        repo.onCreate = { _, _ in try await server.wait() }
        try sut.submit(text: "hi", imageURLString: nil)

        repo.onFeed = { _, _ in FeedPage(posts: [TestData.post(id: "srv-1")] + TestData.posts(1...3), nextCursor: nil) }
        await sut.refresh()
        server.complete(.success(TestData.post(id: "srv-1", text: "hi")))
        await sut.settleCreates()

        #expect(sut.posts.filter { $0.id == "srv-1" }.count == 1)
    }

    @Test func pendingPostsCannotBeLikedAndRowsListPendingFirst() async throws {
        let sut = await loadedSUT()
        repo.onCreate = { _, _ in throw FeedError.server }
        try sut.submit(text: "hi", imageURLString: nil)
        await sut.settleCreates()

        sut.toggleLike(postID: sut.pendingPosts[0].id.uuidString)
        #expect(repo.likeCalls.isEmpty)
    }
}
