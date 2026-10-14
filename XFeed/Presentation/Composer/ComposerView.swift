import SwiftUI
import Kingfisher

struct ComposerView: View {
    @State var viewModel: ComposerViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ComposerViewModel) { _viewModel = State(initialValue: viewModel) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $viewModel.text).frame(minHeight: 120)
                } footer: {
                    Text("\(viewModel.remaining)")
                        .foregroundStyle(viewModel.remaining < 0 ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Section("Image URL (optional)") {
                    TextField("https://…", text: $viewModel.imageURLString)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    if viewModel.hasImageURLError {
                        Text("Enter a valid http(s) image URL").font(.footnote).foregroundStyle(.red)
                    }
                    if let url = viewModel.previewURL {
                        KFImage(url).resizable().scaledToFit().frame(maxHeight: 160).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                if let message = viewModel.errorMessage {
                    Text(message).foregroundStyle(.red)
                }
            }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { if viewModel.post() { dismiss() } }.disabled(!viewModel.canPost)
                }
            }
        }
    }
}
