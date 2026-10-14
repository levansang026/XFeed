import Foundation
@testable import XFeed

enum TestData {
    static let me = Author(id: "me", name: "Bill Le", handle: "billle", avatarURL: nil)

    static func post(
        id: String, text: String = "text", imageURL: URL? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1_000), likeCount: Int = 0, isLiked: Bool = false
    ) -> Post {
        Post(id: id, author: me, text: text, imageURL: imageURL, createdAt: createdAt,
             likeCount: likeCount, isLikedByMe: isLiked)
    }
}

extension TestData {
    static func posts(_ ids: ClosedRange<Int>) -> [Post] { ids.map { post(id: "p\($0)") } }
    static func page(_ ids: ClosedRange<Int>, next: String?) -> FeedPage { FeedPage(posts: posts(ids), nextCursor: next) }
}
