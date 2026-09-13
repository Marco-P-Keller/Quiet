import SwiftUI

/// The furniture the two settings screens are built out of.
///
/// It lived inside `PanelView` for as long as there was one screen, which was
/// right until there were two. Splitting the panel — the day and the days
/// behind you in front, everything else a tap away — would otherwise have meant
/// a second copy of a running head, a row and a rule, and two copies of a
/// hairline are two hairlines that drift apart.
///
/// Internal rather than private-to-a-file for the same reason. Nothing here
/// knows about a session or a preference; they are shapes.

/// The distances the page is built out of, in one place, because a rhythm
/// is a thing you can only keep if the numbers keeping it have names.
enum Metric {
    /// Over a running head. Doing the work nine identical rules used to do,
    /// and doing it better.
    static let betweenGroups: CGFloat = 34
    /// Under a running head, before the first thing it names.
    static let underHeading: CGFloat = 14
    /// Between a control and the sentence explaining it.
    static let underControl: CGFloat = 10
    /// Over and under the words in a row you can press. Two of these plus a
    /// line of body text is a comfortable target on glass.
    static let rowPadding: CGFloat = 14
}

/// A running head: small, tracked capitals in soft ink.
///
/// The capitals are the whole point. This page is nine tenths prose, and
/// every other way of marking a heading — bigger, bolder, a different face —
/// still leaves something the eye reads as a sentence and has to finish
/// before it knows it was a label. Small capitals are read as a label
/// before they are read at all, which is what a running head is for. They
/// grow with the reader's text size like everything else, and VoiceOver
/// gets the string as it was written, not as it is drawn.
struct Cluster<Content: View>: View {
    private let heading: LocalizedStringKey
    private let content: Content

    init(_ heading: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.heading = heading
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.underHeading) {
            Text(heading)
                .font(.quietSmall.weight(.medium))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Metric.betweenGroups)
    }
}

/// A rule between two rows of the same table, and nowhere else.
struct Hairline: View {
    var body: some View {
        Divider().overlay(Paper.rule)
    }
}

/// A row that takes you somewhere: it has a chevron, and the chevron means
/// what it means everywhere else on a phone.
///
/// The name and the value share a line, and stop sharing one when they
/// cannot. At the largest text sizes "Daily limit" and "20 minutes" both
/// wrap, and a row of two two-line columns fighting over the same width is
/// not a row any more — the accessibility screenshot is where that shows
/// up, and it showed up. Past the ordinary sizes the value goes underneath
/// the name, where each of them gets the whole width.
struct Step: View {
    private let title: LocalizedStringKey
    private let value: String?
    private let identifier: String
    private let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    init(
        _ title: LocalizedStringKey,
        value: String? = nil,
        identifier: String = "",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                        if let value {
                            Text(value)
                                .foregroundStyle(Paper.inkSoft)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                } else {
                    Text(title)
                    Spacer(minLength: 8)
                    if let value {
                        Text(value)
                            .foregroundStyle(Paper.inkSoft)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.quietSmall.weight(.semibold))
                    .foregroundStyle(Paper.inkSoft)
            }
            .font(.quietBody)
            .padding(.vertical, Metric.rowPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// A row where something happens rather than one that goes somewhere, so no
/// chevron — and no red either. The two that deserve a warning ask for
/// confirmation, and a warning belongs in the question, not on the handle.
struct Door: View {
    private let title: LocalizedStringKey
    private let isEnabled: Bool
    private let action: () -> Void

    init(_ title: LocalizedStringKey, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.quietBody)
                .foregroundStyle(isEnabled ? Paper.ink : Paper.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Metric.rowPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// One sentence in the small, soft register the whole page explains itself in.
struct Note: View {
    let text: Text

    /// A literal, so that it is translated. `Text(someString)` is verbatim
    /// by design, which is right for a version number and wrong for a
    /// sentence — hence the two ways in.
    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(verbatim: String) { text = Text(verbatim: verbatim) }

    var body: some View {
        text
            .font(.quietFine)
            .foregroundStyle(Paper.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }
}
