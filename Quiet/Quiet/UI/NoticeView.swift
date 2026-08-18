import SwiftUI

/// A sentence, for three seconds, at the top of the screen.
///
/// Used for the two things the app has to say while you are reading: that a tap
/// was refused, and that time is nearly up. No badge, no sound, no haptic, and
/// nothing to dismiss — anything that has to be acknowledged is a thing that
/// interrupts twice.
@MainActor
struct NoticeView: View {
    var notice: Notice
    var onExpire: (Int) -> Void

    private static let lifetime: Duration = .seconds(3)

    var body: some View {
        Text(notice.text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Paper.page)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Paper.ink.opacity(0.92))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: notice.token) {
                try? await Task.sleep(for: Self.lifetime)
                guard !Task.isCancelled else { return }
                onExpire(notice.token)
            }
    }
}
