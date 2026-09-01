import CoreGraphics

/// Which of a page's two edges a thumb is allowed to drag past.
///
/// Quiet keeps the pull at the top. It is how a feed is asked for again, every
/// list on this phone has done it for fifteen years, and the app goes to some
/// trouble to keep it alive against a web view that takes it away on every
/// load.
///
/// It does not keep the one at the bottom. There is nothing under the last
/// post: dragging into it lifts the page off the glass and shows a rectangle of
/// Quiet's own ground, which is not a place, and the app has just spent a
/// release making sure every other surface says what it is. A scroll view that
/// bounces into empty space is a scroll view suggesting there is something
/// there.
///
/// The difficulty is that `bounces` is one property for both edges, so this
/// cannot be answered edge by edge. It can be answered by *where the page is*.
/// A whole screen of page above you means the top is out of reach — nobody
/// arrives at it without scrolling back through that screen first, and the
/// bounce comes back on the way, long before the top does. So the switch
/// happens in the middle of a page, where no edge is reachable and therefore
/// nothing can be felt.
enum Overscroll {
    /// Whether the scroll view may be dragged past its edges at all.
    ///
    /// - Parameters:
    ///   - travelled: how far the page has been scrolled from its own top,
    ///     with the content inset already taken off.
    ///   - screen: the height of the glass the page is being read through.
    ///
    /// A page shorter than about a screen and a half keeps its bottom bounce,
    /// and that is deliberate rather than overlooked. On a profile with four
    /// posts there is no screen of page to be below, so the only rule that
    /// could take the bottom bounce away would take the pull with it — and the
    /// empty space under four posts is an inch, not a page.
    static func bounces(travelled: CGFloat, screen: CGFloat) -> Bool {
        guard screen > 0 else { return true }
        return travelled < screen
    }
}
