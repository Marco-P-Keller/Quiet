import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// What somebody picked in Screen Time's own list: the Instagram app, and
/// instagram.com in Safari if they chose it too.
///
/// The selection is a set of opaque tokens. Quiet never learns which apps they
/// stand for — iOS shows the names and icons on Quiet's behalf and hands back
/// something Quiet can count and close but cannot read.
typealias Picked = FamilyActivitySelection

extension FamilyActivitySelection {
    /// Whether this names anything Quiet uses. Whole categories are not used:
    /// a category such as "Social" would count Quiet itself as well, and the
    /// time would be counted twice.
    var namesAnything: Bool {
        !applicationTokens.isEmpty || !webDomainTokens.isEmpty
    }

    /// Whether `wanted` covers everything `current` does, which is what makes
    /// a change free rather than something that waits for tomorrow. See
    /// `Reach`.
    static func covers(_ wanted: Picked?, _ current: Picked?) -> Bool {
        guard let current, current.namesAnything else { return true }
        guard let wanted else { return false }
        return wanted.applicationTokens.isSuperset(of: current.applicationTokens)
            && wanted.webDomainTokens.isSuperset(of: current.webDomainTokens)
    }
}

/// Screen Time, doing the two things Quiet asks of it: say how many minutes
/// the Instagram app has had today, and close it when the day is spent.
///
/// Used by the app and by the monitor extension alike, which is the reason it
/// is a set of plain functions over the shelf rather than an object with
/// state: the extension is started cold for every event and keeps nothing.
///
/// iOS 17.4, because that is where a threshold can be told to count the time
/// that passed before it was set (`includesPastActivity`). Without that, every
/// change to the limit would restart the count from zero mid-afternoon and the
/// Instagram app would get a second allowance.
@available(iOS 17.4, *)
enum ScreenTime {
    static let activity = DeviceActivityName("quiet.day")

    /// Quiet's own store of restrictions, by name, so that clearing it can
    /// never touch anything else that is managing this phone.
    static var store: ManagedSettingsStore { ManagedSettingsStore(named: .init("quiet")) }

    /// How early a closing may be lifted. The schedule's own day starts at four
    /// sharp, and the call that says so may arrive a moment before it does;
    /// lifting a few minutes early is better than keeping the app shut all day
    /// because a callback beat the clock by a second.
    static let grace: TimeInterval = 15 * 60

    // MARK: - The reach

    static func storedReach() -> Reach<Picked> {
        Shelf.load(Reach<Picked>.self, Shelf.Key.reach) ?? Reach()
    }

    static func saveReach(_ reach: Reach<Picked>) {
        Shelf.save(reach, Shelf.Key.reach)
    }

    // MARK: - Closing and opening

    /// The moment the Instagram app opens again, while it is closed.
    static var closedUntil: Date? {
        Shelf.load(Date.self, Shelf.Key.closedUntil)
    }

    /// Close whatever the limit reaches, until `until`.
    static func close(until: Date, today: DayKey) {
        let reach = storedReach().rolled(to: today)
        guard let picked = reach.current, picked.namesAnything else { return }
        let store = store
        store.shield.applications = picked.applicationTokens.isEmpty ? nil : picked.applicationTokens
        store.shield.webDomains = picked.webDomainTokens.isEmpty ? nil : picked.webDomainTokens
        Shelf.save(until, Shelf.Key.closedUntil)
    }

    /// Open everything Quiet has closed.
    static func open() {
        store.clearAllSettings()
        Shelf.save(Optional<Date>.none, Shelf.Key.closedUntil)
    }

    // MARK: - What the extension is woken for

    /// A day may have begun: open what was closed for a day that has ended,
    /// and let a narrowing of the reach that has come due take over.
    ///
    /// Called at four in the morning by the extension and whenever the app
    /// comes forward, so it must be harmless to call at any time — and it is
    /// also called when monitoring is (re)started in the middle of a day,
    /// which is why it opens nothing whose day is still running.
    static func morning(now: Date, today: DayKey) {
        if let until = closedUntil, now >= until.addingTimeInterval(-grace) {
            open()
        }
        let stored = storedReach()
        let rolled = stored.rolled(to: today)
        guard rolled != stored else { return }
        saveReach(rolled)
        let top = Shelf.load(Terms.self, Shelf.Key.terms).map { Milestones.top(for: $0.limit) } ?? 0
        watch(rolled.current, top: top)
    }

    /// Screen Time says the apps the limit reaches have had `minutes` today.
    static func reached(_ minutes: Int, now: Date, today: DayKey) {
        let before = Shelf.load(Tally.self, Shelf.Key.tally) ?? Tally(day: today, minutes: 0)
        let tally = before.reaching(minutes, on: today)
        if tally != before { Shelf.save(tally, Shelf.Key.tally) }
        let terms = Shelf.load(Terms.self, Shelf.Key.terms)
        guard Verdict.isOver(tally: tally, terms: terms, today: today) else { return }
        close(until: today.end(), today: today)
    }

    // MARK: - Watching

    /// What is being watched for, so that asking again for the same thing is
    /// free. Starting monitoring again makes Screen Time repeat every threshold
    /// already passed today, which is harmless but not free.
    private struct Watched: Codable, Equatable {
        var top: Int
        var picked: Picked
    }

    /// Ask Screen Time to report each minute the picked apps are used, up to
    /// `top`, in days that turn at four in the morning like Quiet's do.
    static func watch(_ picked: Picked?, top: Int) {
        let center = DeviceActivityCenter()
        guard let picked, picked.namesAnything, top > 0 else {
            center.stopMonitoring([activity])
            Shelf.save(Optional<Watched>.none, Shelf.Key.watched)
            return
        }

        let wanted = Watched(top: top, picked: picked)
        if Shelf.load(Watched.self, Shelf.Key.watched) == wanted,
           center.activities.contains(activity) {
            return
        }

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for mark in Milestones.marks(upTo: top) {
            events[DeviceActivityEvent.Name(Milestones.name(mark))] = DeviceActivityEvent(
                applications: picked.applicationTokens,
                webDomains: picked.webDomainTokens,
                threshold: DateComponents(hour: mark / 60, minute: mark % 60),
                includesPastActivity: true
            )
        }

        // Four in the morning to a second before four the next morning: the
        // day Quiet means, so a minute in the Instagram app at one a.m. belongs
        // to the evening it was spent in, exactly as a minute in Quiet does.
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: QuietDay.startHour, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: QuietDay.startHour - 1, minute: 59, second: 59),
            repeats: true
        )

        do {
            try center.startMonitoring(activity, during: schedule, events: events)
            Shelf.save(wanted, Shelf.Key.watched)
            Shelf.save(Optional<String>.none, Shelf.Key.trouble)
        } catch {
            Shelf.save(String(describing: error), Shelf.Key.trouble)
        }
    }

    /// Everything Quiet asked of Screen Time, taken back.
    static func forget() {
        watch(nil, top: 0)
        open()
        for key in [Shelf.Key.terms, Shelf.Key.tally, Shelf.Key.reach, Shelf.Key.trouble] {
            Shelf.defaults.removeObject(forKey: key)
        }
    }
}
