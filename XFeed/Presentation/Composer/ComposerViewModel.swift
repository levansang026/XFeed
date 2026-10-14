import Foundation
import Observation

@MainActor
@Observable
final class ComposerViewModel {
    var text = ""
    var imageURLString = ""
    private(set) var errorMessage: String?

    @ObservationIgnored private let onSubmit: (String, String?) throws -> Void

    init(onSubmit: @escaping (String, String?) throws -> Void) {
        self.onSubmit = onSubmit
    }

    var remaining: Int { CreatePost.maxLength - text.trimmingCharacters(in: .whitespacesAndNewlines).count }

    var previewURL: URL? { (try? CreatePost.parseImageURL(imageURLString)) ?? nil }

    var hasImageURLError: Bool {
        do { _ = try CreatePost.parseImageURL(imageURLString); return false } catch { return true }
    }

    var canPost: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && remaining >= 0 && !hasImageURLError
    }

    /// Returns `true` when the post was handed off and the Composer can close.
    func post() -> Bool {
        do {
            try onSubmit(text, imageURLString)
            return true
        } catch let error as CreatePostError {
            errorMessage = switch error {
            case .emptyText: "Write something first."
            case .tooLong: "Posts can be at most \(CreatePost.maxLength) characters."
            case .invalidImageURL: "That image URL doesn't look right."
            }
            return false
        } catch {
            errorMessage = "Something went wrong."
            return false
        }
    }
}
