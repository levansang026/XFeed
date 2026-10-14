import SwiftUI
import Kingfisher

struct PostRowView: View {
    let post: Post
    let onLike: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(url: post.author.avatarURL, size: 44)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(post.author.name).fontWeight(.bold).lineLimit(1)
                    Text("@\(post.author.handle)").foregroundStyle(.secondary).lineLimit(1)
                    Text("· \(RelativeTimeFormatter.string(from: post.createdAt))").foregroundStyle(.secondary)
                }
                .font(.subheadline)
                Text(post.text).font(.body)
                if let imageURL = post.imageURL { PostImageView(url: imageURL) }
                LikeButton(isLiked: post.isLikedByMe, count: post.likeCount, action: onLike)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
    }
}

struct LikeButton: View {
    let isLiked: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("\(count)", systemImage: isLiked ? "heart.fill" : "heart")
                .font(.subheadline)
                .foregroundStyle(isLiked ? Color.pink : Color.secondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: isLiked)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .accessibilityLabel(isLiked ? "Unlike, \(count) likes" : "Like, \(count) likes")
    }
}

struct AvatarView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        KFImage(url)
            .placeholder { Circle().fill(.quaternary) }
            .fade(duration: 0.15)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

struct PostImageView: View {
    let url: URL
    @State private var failed = false

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if failed {
                Image(systemName: "photo.badge.exclamationmark").font(.title).foregroundStyle(.secondary)
            } else {
                KFImage(url)
                    .onFailure { _ in failed = true }
                    .placeholder { ProgressView() }
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.separator, lineWidth: 0.5))
        .accessibilityLabel("Post image")
    }
}
