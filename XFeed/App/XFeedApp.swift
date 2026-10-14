import SwiftUI
import Kingfisher

@main
struct XFeedApp: App {
    @State private var container = AppContainer.live()

    init() {
        // Keep decoded images bounded; Kingfisher also drops them on memory warnings.
        ImageCache.default.memoryStorage.config.totalCostLimit = 80 * 1024 * 1024
        ImageCache.default.memoryStorage.config.countLimit = 100
    }

    var body: some Scene {
        WindowGroup {
            FeedView(viewModel: container.feed, me: container.me, mockController: container.mockController)
        }
    }
}
