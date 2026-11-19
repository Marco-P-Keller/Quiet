import FamilyControls
import Foundation
import Observation

/// The limit, reaching the Instagram app through Screen Time.
///
/// Off until somebody switches it on, and then three things happen that are
/// all iOS's rather than Quiet's: iOS asks whether Quiet may use Screen Time,
/// iOS shows its own list of apps for the Instagram app to be picked from, and
/// iOS hands back a token Quiet can count and close but cannot read. Quiet
/// never learns what else is on the phone, and nothing about it leaves the
/// phone.
///
/// What Quiet then does with it is one sum. Time in the Instagram app and time
/// in Quiet are added together against the one limit; when they reach it the
/// curtain comes down in Quiet and Screen Time closes the Instagram app, until
/// four in the morning. The minutes the Instagram app had also show in the
/// panel and in the days behind you, because they are the same day.
///
/// Reaching further is free and reaching less waits for tomorrow — see
/// `Reach` — so this cannot be switched off in the moment it starts to bite.
/// Taking Quiet's Screen Time access away in iOS Settings can, at any time, and
/// Quiet does not pretend otherwise: that is iOS's door, and it is the right one
/// for iOS to keep.
@MainActor
@Observable
final class InstagramAppLimit: InstagramAppDoor {
    /// Whether this phone can do it at all. See `ScreenTime` for why 17.4.
    let isSupported: Bool

    /// Whether Quiet may use Screen Time, as iOS last said.
    private(set) var status: AuthorizationStatus

    /// What the limit reaches, rolled up to the day it was last asked about.
    private(set) var reach: Reach<Picked>

    /// Why the last attempt to switch it on did not work, in iOS's words.
    private(set) var trouble: String?

    /// The highest minute last asked to be watched for, so that a limit
    /// written every five seconds is not a new request to Screen Time every
    /// five seconds.
    @ObservationIgnored private var watchedTop: Int?

    init() {
        if #available(iOS 17.4, *) {
            isSupported = true
            reach = ScreenTime.storedReach()
        } else {
            isSupported = false
            reach = Reach()
        }
        status = AuthorizationCenter.shared.authorizationStatus
    }

    /// Whether the limit reaches the Instagram app today.
    var isOn: Bool { reach.current?.namesAnything ?? false }

    /// Whether Quiet may use Screen Time now.
    var isAllowed: Bool { status == .approved }

    /// Look again at what iOS says and what is stored, for a settings screen
    /// that has just come forward. Somebody may have been to iOS Settings.
    func refresh(today: DayKey) {
        status = AuthorizationCenter.shared.authorizationStatus
        if #available(iOS 17.4, *) {
            reach = ScreenTime.storedReach().rolled(to: today)
        }
    }

    /// Ask iOS for Screen Time. iOS shows its own sheet, once; after that the
    /// answer lives in iOS Settings › Screen Time.
    func askForAccess() async -> Bool {
        trouble = nil
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            trouble = error.localizedDescription
        }
        status = AuthorizationCenter.shared.authorizationStatus
        return isAllowed
    }

    /// Reach `picked` — or, with `nil`, nothing beyond Quiet.
    ///
    /// More applies at once, and if today is already spent the newly reached
    /// apps close at once too: the limit does not owe anybody the rest of a day
    /// they have already used. Less applies from tomorrow.
    func choose(_ picked: Picked?, today: DayKey, isSpent: Bool, until: Date) {
        guard #available(iOS 17.4, *) else { return }
        let wanted = picked?.namesAnything == true ? picked : nil
        reach = ScreenTime.storedReach().requesting(wanted, today: today, covers: Picked.covers)
        ScreenTime.saveReach(reach)
        let top = Shelf.load(Terms.self, Shelf.Key.terms).map { Milestones.top(for: $0.limit) } ?? 0
        ScreenTime.watch(reach.current, top: top)
        watchedTop = top
        if isSpent { ScreenTime.close(until: until, today: today) }
    }

    /// What Screen Time said went wrong the last time it was asked to watch,
    /// if anything did.
    var watchTrouble: String? {
        Shelf.load(String.self, Shelf.Key.trouble)
    }

    // MARK: - InstagramAppDoor

    func minutes(on day: DayKey) -> Int {
        guard let tally = Shelf.load(Tally.self, Shelf.Key.tally), tally.day == day else { return 0 }
        return tally.minutes
    }

    func tell(_ terms: Terms) {
        Shelf.save(terms, Shelf.Key.terms)
        let top = Milestones.top(for: terms.limit)
        guard #available(iOS 17.4, *), top != watchedTop else { return }
        watchedTop = top
        ScreenTime.watch(ScreenTime.storedReach().rolled(to: terms.day).current, top: top)
    }

    func close(until: Date, today: DayKey) {
        guard #available(iOS 17.4, *) else { return }
        ScreenTime.close(until: until, today: today)
    }

    func morning(now: Date, today: DayKey) {
        guard #available(iOS 17.4, *) else { return }
        ScreenTime.morning(now: now, today: today)
        reach = ScreenTime.storedReach()
    }

    func forget() {
        guard #available(iOS 17.4, *) else { return }
        ScreenTime.forget()
        reach = Reach()
        watchedTop = nil
    }
}
