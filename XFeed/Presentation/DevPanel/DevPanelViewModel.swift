import Foundation
import Observation

@MainActor
@Observable
final class DevPanelViewModel {
    var failurePercent: Double = 0
    var minLatency: Double = 0
    var maxLatency: Double = 0

    @ObservationIgnored private let controller: any MockControlling
    @ObservationIgnored private let onReset: () async -> Void

    init(controller: any MockControlling, onReset: @escaping () async -> Void) {
        self.controller = controller
        self.onReset = onReset
    }

    func load() async {
        let config = await controller.currentConfig()
        failurePercent = (config.failureRate * 100).rounded()
        minLatency = config.minLatency
        maxLatency = config.maxLatency
    }

    func apply() async {
        await controller.update(MockConfig(
            failureRate: failurePercent / 100, minLatency: minLatency, maxLatency: max(minLatency, maxLatency)))
    }

    func forceNextFailure() async { await controller.forceNextRequestToFail() }

    func resetData() async {
        await controller.resetToSeedData()
        await onReset()
    }
}
