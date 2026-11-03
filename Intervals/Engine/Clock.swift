import Foundation

/// Source of wall-clock time for the engine. The engine never keeps its own
/// counter; everything is derived from `now` and stored timestamps.
protocol WallClock: Sendable {
    var now: Date { get }
}

struct SystemClock: WallClock {
    var now: Date { Date() }
}

/// A clock tests can move by hand to simulate sleep, quit, or the passage of time.
final class ManualClock: WallClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        current = start
    }

    var now: Date {
        lock.withLock { current }
    }

    func advance(_ seconds: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(seconds) }
    }
}
