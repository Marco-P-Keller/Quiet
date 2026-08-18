import SwiftUI

/// The end of the day.
///
/// There is no "5 more minutes", no "just this once", no countdown to watch and
/// no way to argue. The only thing on this screen worth doing is putting the
/// phone down, so the screen offers nothing else.
///
/// The one door out leads to the panel, and it is safe to leave open: no change
/// made there can return time to today. Asking for more always starts tomorrow.
struct CurtainView: View {
    var limitMinutes: Int
    var resetsAt: Date
    var onOpenPanel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("That's all\nfor today.")
                .font(.quietTitle(38))
                .lineSpacing(8)

            Text("You asked for \(Phrase.minutes(limitMinutes)) a day. Quiet opens again at \(Phrase.clockTime(resetsAt)).")
                .font(.system(size: 15))
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)

            Spacer()

            Button("Settings", action: onOpenPanel)
                .font(.system(size: 14))
                .foregroundStyle(Paper.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
        .quietPage()
    }
}

#Preview {
    CurtainView(limitMinutes: 20, resetsAt: .now, onOpenPanel: {})
}
