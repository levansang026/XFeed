import Testing
@testable import XFeed

@MainActor
@Suite struct ComposerViewModelTests {
    func makeSUT(failWith error: CreatePostError? = nil) -> (ComposerViewModel, Box) {
        let box = Box()
        let sut = ComposerViewModel { text, url in
            if let error { throw error }
            box.submitted.append((text, url))
        }
        return (sut, box)
    }

    final class Box { var submitted: [(String, String?)] = [] }

    @Test func cannotPostEmptyOrWhitespaceText() {
        let (sut, _) = makeSUT()
        #expect(!sut.canPost)
        sut.text = "  \n "
        #expect(!sut.canPost)
        sut.text = "hi"
        #expect(sut.canPost)
    }

    @Test func remainingCountsDownFrom280AndBlocksOverflow() {
        let (sut, _) = makeSUT()
        sut.text = String(repeating: "a", count: 280)
        #expect(sut.remaining == 0 && sut.canPost)
        sut.text += "a"
        #expect(sut.remaining == -1 && !sut.canPost)
    }

    @Test func invalidImageURLBlocksPostingAndFlagsTheField() {
        let (sut, _) = makeSUT()
        sut.text = "hi"
        sut.imageURLString = "not a url"
        #expect(sut.hasImageURLError && !sut.canPost && sut.previewURL == nil)

        sut.imageURLString = "https://picsum.photos/id/10/800/600"
        #expect(!sut.hasImageURLError && sut.canPost)
        #expect(sut.previewURL?.absoluteString == "https://picsum.photos/id/10/800/600")
    }

    @Test func blankImageURLIsNotAnError() {
        let (sut, _) = makeSUT()
        sut.text = "hi"
        sut.imageURLString = "   "
        #expect(!sut.hasImageURLError && sut.canPost)
    }

    @Test func postForwardsInputAndReportsSuccess() {
        let (sut, box) = makeSUT()
        sut.text = "hello"
        sut.imageURLString = "https://picsum.photos/id/1/1/1"
        #expect(sut.post())
        #expect(box.submitted.count == 1 && box.submitted[0].0 == "hello")
    }

    @Test func postFailureKeepsTheDraftAndShowsAnError() {
        let (sut, _) = makeSUT(failWith: .tooLong)
        sut.text = "hello"
        #expect(!sut.post())
        #expect(sut.text == "hello" && sut.errorMessage != nil)
    }
}
