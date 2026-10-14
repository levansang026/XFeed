import Testing
import Foundation
@testable import XFeed

@Suite struct CreatePostUseCaseTests {
    @Test func trimsTextAndForwardsToRepository() async throws {
        let repo = FakeFeedRepository()
        let sut = CreatePost(repository: repo)

        _ = try await sut(text: "  hello  \n", imageURLString: nil)

        #expect(repo.createdPosts.map(\.text) == ["hello"])
        #expect(repo.createdPosts.first?.imageURL == nil)
    }

    @Test func rejectsWhitespaceOnlyText() async {
        let sut = CreatePost(repository: FakeFeedRepository())
        await #expect(throws: CreatePostError.emptyText) {
            try await sut(text: " \n ", imageURLString: nil)
        }
    }

    @Test func rejectsTextOver280Characters() async {
        let sut = CreatePost(repository: FakeFeedRepository())
        await #expect(throws: CreatePostError.tooLong) {
            try await sut(text: String(repeating: "a", count: 281), imageURLString: nil)
        }
    }

    @Test func accepts280Characters() async throws {
        let sut = CreatePost(repository: FakeFeedRepository())
        _ = try await sut(text: String(repeating: "a", count: 280), imageURLString: nil)
    }

    @Test(arguments: ["not a url", "ftp://x.com/a.png", "https://", "picsum.photos/a.jpg"])
    func rejectsMalformedImageURL(_ value: String) async {
        let sut = CreatePost(repository: FakeFeedRepository())
        await #expect(throws: CreatePostError.invalidImageURL) {
            try await sut(text: "hi", imageURLString: value)
        }
    }

    @Test func blankImageURLMeansNoImage() async throws {
        let repo = FakeFeedRepository()
        let sut = CreatePost(repository: repo)
        _ = try await sut(text: "hi", imageURLString: "   ")
        #expect(repo.createdPosts.first?.imageURL == nil)
    }

    @Test func forwardsValidImageURL() async throws {
        let repo = FakeFeedRepository()
        let sut = CreatePost(repository: repo)
        _ = try await sut(text: "hi", imageURLString: " https://picsum.photos/id/10/800/600 ")
        #expect(repo.createdPosts.first?.imageURL == URL(string: "https://picsum.photos/id/10/800/600"))
    }
}
