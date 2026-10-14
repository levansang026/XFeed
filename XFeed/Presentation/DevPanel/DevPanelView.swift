import SwiftUI

struct DevPanelView: View {
    @State var viewModel: DevPanelViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: DevPanelViewModel) { _viewModel = State(initialValue: viewModel) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Failure rate: \(Int(viewModel.failurePercent))%") {
                    Slider(value: $viewModel.failurePercent, in: 0...100, step: 5)
                }
                Section("Latency (seconds)") {
                    Stepper("Min: \(viewModel.minLatency, specifier: "%.1f")", value: $viewModel.minLatency, in: 0...5, step: 0.1)
                    Stepper("Max: \(viewModel.maxLatency, specifier: "%.1f")", value: $viewModel.maxLatency, in: 0...5, step: 0.1)
                }
                Section {
                    Button("Force next request to fail") { Task { await viewModel.forceNextFailure(); dismiss() } }
                    Button("Reset to seed data", role: .destructive) { Task { await viewModel.resetData(); dismiss() } }
                }
            }
            .navigationTitle("Dev panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await viewModel.load() }
            .onChange(of: viewModel.failurePercent) { _, _ in Task { await viewModel.apply() } }
            .onChange(of: viewModel.minLatency) { _, _ in Task { await viewModel.apply() } }
            .onChange(of: viewModel.maxLatency) { _, _ in Task { await viewModel.apply() } }
        }
    }
}
