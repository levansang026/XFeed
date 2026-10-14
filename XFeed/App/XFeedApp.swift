import SwiftUI

@main
struct XFeedApp: App {
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            FeedView(viewModel: container.feed, me: container.me, mockController: container.mockController)
        }
    }
}
