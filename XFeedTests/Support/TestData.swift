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
