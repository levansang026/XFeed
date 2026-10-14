import Testing
@testable import XFeed

actor FakeMockController: MockControlling {
    var config = MockConfig(failureRate: 0.15, minLatency: 0.4, maxLatency: 1.2)
    var forced = 0
    var resets = 0
    func currentConfig() -> MockConfig { config }
    func update(_ config: MockConfig) { self.config = config }
    func forceNextRequestToFail() { forced += 1 }
    func resetToSeedData() { resets += 1 }
}

@MainActor
@Suite struct DevPanelViewModelTests {
    @Test func loadsCurrentConfigAsPercentAndSeconds() async {
        let sut = DevPanelViewModel(controller: FakeMockController(), onReset: {})
        await sut.load()
        #expect(sut.failurePercent == 15)
        #expect(sut.minLatency == 0.4 && sut.maxLatency == 1.2)
    }

    @Test func applyPushesConfigToTheMock() async {
        let controller = FakeMockController()
        let sut = DevPanelViewModel(controller: controller, onReset: {})
        await sut.load()
        sut.failurePercent = 50
        sut.minLatency = 1
        sut.maxLatency = 2
        await sut.apply()
        #expect(await controller.config == MockConfig(failureRate: 0.5, minLatency: 1, maxLatency: 2))
    }

    @Test func maxLatencyNeverDropsBelowMin() async {
        let controller = FakeMockController()
        let sut = DevPanelViewModel(controller: controller, onReset: {})
        await sut.load()
        sut.minLatency = 2
        sut.maxLatency = 1
        await sut.apply()
        #expect(await controller.config.maxLatency == 2)
    }

    @Test func forceNextFailureAndResetAreForwarded() async {
        let controller = FakeMockController()
        nonisolated(unsafe) var refreshed = 0
        let sut = DevPanelViewModel(controller: controller, onReset: { refreshed += 1 })
        await sut.forceNextFailure()
        await sut.resetData()
        let forced = await controller.forced
        let resets = await controller.resets
        #expect(forced == 1 && resets == 1)
        #expect(refreshed == 1)
    }
}
