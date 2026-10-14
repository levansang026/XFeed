import SwiftUI

struct PendingPostRowView: View {
    let pending: PendingPost
    let author: Author
    let onRetry: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(url: author.avatarURL, size: 44)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(author.name).fontWeight(.bold)
                    Text("@\(author.handle)").foregroundStyle(.secondary)
                }
                .font(.subheadline)
                Text(pending.text)
                if let url = pending.imageURL { PostImageView(url: url) }
                if case .failed = pending.status { failureBar }
            }
            .blur(radius: pending.status == .sending ? 2 : 0)
            .overlay { if pending.status == .sending { ProgressView() } }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(pending.status == .sending ? 0.7 : 1)
    }

    private var failureBar: some View {
        HStack {
            Label("Couldn't post", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.red).font(.subheadline)
            Spacer()
            Button("Retry", action: onRetry).buttonStyle(.bordered)
            Button("Discard", role: .destructive, action: onDiscard).buttonStyle(.bordered)
        }
    }
}
