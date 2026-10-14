import SwiftUI

struct FeedView: View {
    let viewModel: FeedViewModel
    let me: Author
    let mockController: (any MockControlling)?

    @State private var showComposer = false
    @State private var showDevPanel = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        AvatarView(url: me.avatarURL, size: 32)
                            .onTapGesture(count: 3) { if mockController != nil { showDevPanel = true } }
                    }
                }
                .overlay(alignment: .bottomTrailing) { composeButton }
                .overlay(alignment: .bottom) { errorBanner }
        }
        .task { await viewModel.loadInitial() }
        .sheet(isPresented: $showComposer) {
            ComposerView(viewModel: ComposerViewModel { text, url in
                try viewModel.submit(text: text, imageURLString: url)
            })
        }
        .sheet(isPresented: $showDevPanel) {
            if let mockController {
                DevPanelView(viewModel: DevPanelViewModel(controller: mockController) { await viewModel.refresh() })
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ContentUnavailableView {
                Label("Couldn't load your feed", systemImage: "wifi.exclamationmark")
            } actions: {
                Button("Try again") { Task { await viewModel.loadInitial() } }.buttonStyle(.borderedProminent)
            }
        case .loaded:
            if viewModel.posts.isEmpty && viewModel.pendingPosts.isEmpty {
                ContentUnavailableView("No posts yet", systemImage: "text.bubble")
            } else {
                list
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.pendingPosts) { pending in
                    PendingPostRowView(
                        pending: pending, author: me,
                        onRetry: { viewModel.retry(pendingID: pending.id) },
                        onDiscard: { viewModel.discard(pendingID: pending.id) })
                    Divider()
                }
                ForEach(viewModel.posts) { post in
                    PostRowView(post: post) { viewModel.toggleLike(postID: post.id) }
                        .task { await viewModel.loadMoreIfNeeded(currentPostID: post.id) }
                    Divider()
                }
                footer
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder private var footer: some View {
        switch viewModel.loadMore {
        case .loading:
            ProgressView().padding(24)
        case .failed:
            Button("Couldn't load more. Tap to retry") { Task { await viewModel.retryLoadMore() } }
                .padding(24)
        case .ended:
            Text("You're all caught up").font(.footnote).foregroundStyle(.secondary).padding(24)
        case .idle:
            Color.clear.frame(height: 24)
        }
    }

    private var composeButton: some View {
        Button { showComposer = true } label: {
            Image(systemName: "plus").font(.title2.bold()).foregroundStyle(.white)
                .frame(width: 56, height: 56).background(Color.accentColor, in: Circle()).shadow(radius: 4, y: 2)
        }
        .padding(20)
        .accessibilityLabel("New post")
    }

    @ViewBuilder private var errorBanner: some View {
        if let message = viewModel.errorMessage {
            Text(message)
                .font(.subheadline).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.black.opacity(0.85), in: Capsule())
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task { try? await Task.sleep(for: .seconds(3)); viewModel.dismissError() }
        }
    }
}
