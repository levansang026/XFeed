import Foundation

struct MockConfig: Equatable, Sendable {
    var failureRate: Double
    var minLatency: Double
    var maxLatency: Double

    static let `default` = MockConfig(failureRate: 0.15, minLatency: 0.4, maxLatency: 1.2)
}

/// Implemented only by the mock backend; Presentation never sees a mock type.
protocol MockControlling: Sendable {
    func currentConfig() async -> MockConfig
    func update(_ config: MockConfig) async
    func forceNextRequestToFail() async
    func resetToSeedData() async
}
