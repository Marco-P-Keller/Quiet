import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// What stands in front of the Instagram app once Quiet has closed it.
///
/// Without this, iOS shows its own sheet — "Restricted" — which is true and
/// says nothing: not who closed the app, not why, not until when. Somebody
/// meeting that at eleven at night would reasonably think something was
/// broken. This says what the curtain in Quiet says, in Quiet's paper and ink,
/// and when it lifts.
///
/// Nothing here can open the app again. The one button closes the sheet, which
/// is all a button on the far side of the day should do.
final class ShieldConfig: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        sheet()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        sheet()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        sheet()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        sheet()
    }

    private func sheet() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: Self.paper,
            icon: UIImage(systemName: "hourglass")?
                .withTintColor(Self.ink, renderingMode: .alwaysOriginal),
            title: .init(text: String(localized: "That's all for today."), color: Self.ink),
            subtitle: .init(text: Self.subtitle, color: Self.inkSoft),
            primaryButtonLabel: .init(text: String(localized: "OK"), color: Self.paper),
            primaryButtonBackgroundColor: Self.ink
        )
    }

    /// When it opens again, if Quiet wrote that down; four in the morning if not,
    /// which is the same moment said less precisely.
    private static var subtitle: String {
        let until: Date
        if #available(iOS 17.4, *), let closed = ScreenTime.closedUntil {
            until = closed
        } else {
            until = DayKey(Date()).end()
        }
        let time = until.formatted(date: .omitted, time: .shortened)
        return String(localized: "Quiet has closed it for the rest of the day: your daily minutes are spent, here and in Quiet together. It opens again at \(time).")
    }

    // The app's own paper and ink, by day and by night. Copied rather than
    // shared because the app's live in SwiftUI and this sheet is drawn by iOS
    // from UIKit colours; see `Paper` in the app for why they are these.
    private static let paper = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.059, green: 0.067, blue: 0.078, alpha: 1)
            : UIColor(red: 0.969, green: 0.957, blue: 0.937, alpha: 1)
    }

    private static let ink = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.937, green: 0.925, blue: 0.902, alpha: 1)
            : UIColor(red: 0.106, green: 0.098, blue: 0.086, alpha: 1)
    }

    private static let inkSoft = ink.withAlphaComponent(0.55)
}
