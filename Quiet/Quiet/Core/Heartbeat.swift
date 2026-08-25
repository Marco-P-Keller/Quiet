import Foundation

/// Something that calls back, over and over, until it is told to stop.
///
/// A protocol rather than a `Timer` written into the session, for the same
/// reason `TimeSource` is a protocol rather than a call to `Date()`: the rules
/// that depend on it are the ones this app is *made of*, and a rule that can
/// only be tested by waiting is a rule that is tested rarely, slowly, and
/// flakily on a busy machine.
///
/// What it made untestable was not a detail. Whether the ledger accrues, at
/// what point the app says five minutes remain, whether it says it twice, and
/// whether the curtain arrives on the right second are all things that only
/// happen inside a tick — so none of them had a test that ran the clock. They
/// have one now, and it takes no time at all.
@MainActor
protocol Heartbeat: AnyObject {
    func start(every interval: TimeInterval, _ beat: @escaping @MainActor () -> Void)
    func stop()
}

/// The real one.
@MainActor
final class RunLoopHeartbeat: Heartbeat {
    private var timer: Timer?

    init() {}

    func start(every interval: TimeInterval, _ beat: @escaping @MainActor () -> Void) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor in beat() }
        }
        // `.common` so the count keeps running while a finger is on a scroll
        // view — which is exactly when it matters.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        // Not `stop()`: `deinit` is not on the main actor, and a timer that has
        // outlived its owner has nothing left to call anyway.
        timer?.invalidate()
    }
}
