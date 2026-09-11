import ObjectiveC
import UIKit
import WebKit

/// The bar iOS lays over the page while a field on it has the keyboard,
/// replaced with nothing at all.
///
/// A photograph of a conversation is what this is for. Every box you write into
/// on Instagram is pinned to the bottom of the page — a comment, a search, a
/// message — and iOS 26 draws its form bar as a floating capsule in exactly
/// that strip: two chevrons for stepping between fields, a blue tick for
/// putting the keyboard away. On the phone it comes down on top of the message
/// box. The box's own outline is still visible *through* the capsule, which is
/// how you can tell the page was never given room for it, and the tick lands
/// precisely where Instagram's send button is.
///
/// Which is what made chatting not work rather than merely look wrong. Send was
/// the button underneath. You pressed Done.
///
/// ## Nothing, not nil
///
/// The obvious fix is to answer `inputAccessoryView` with `nil`, and it is
/// wrong, and it is wrong in a way that only a photograph shows. **WebKit stops
/// shrinking the page for the keyboard at all.** Measured on iOS 26.1, on a
/// screen 956 points tall, with one field pinned to the bottom of a page:
///
///     accessory   keyboard frame   innerHeight   box bottom
///     the bar     413 high, top 543   481         473  — above the bar
///     nil         345 high, top 611   860         852  — behind the keyboard
///     nothing     345 high, top 611   549         541  — 62 + 549 = 611
///
/// The middle row is a page that was never resized: 860 is the whole glass. The
/// box goes with it, down behind the keyboard, and the sentence being written
/// is not merely hard to read — it is not on the screen. That is a worse app
/// than the one this file was opened to fix.
///
/// The last row is what ships: an accessory that is *there*, so that every
/// calculation WebKit makes about the keyboard goes on being made, and that is
/// zero points high and draws nothing, so there is no bar. The page ends at
/// 611, which is exactly where the keyboard begins. The message box sits on it.
///
/// ## What it costs
///
/// The chevrons. On the login form they step from the username to the password,
/// and without them that is a tap you make yourself — the one page in this app
/// with two fields on it. Everywhere else there is one field and it is at the
/// bottom of the screen. The keyboard still goes away: a tap on the page
/// outside a field blurs it, which is what the tick did.
///
/// ## How
///
/// There is no supported way to ask for any of it. `inputAccessoryView` is a
/// `UIResponder` property, and the responder answering for a page is WebKit's
/// own `WKContentView` — not a class the app is handed. So a subclass is made
/// at run time, with one method on it, and the view is moved into it. Nothing
/// private is called and nothing is swizzled out from under anybody: one
/// `object_setClass`, on one view, inside a web view this app made and holds
/// the only reference to.
///
/// Everything above is measured rather than believed, in `FormBarTests` —
/// including the two facts WebKit has never promised, that the view is called
/// `WKContentView` and that it stands in the scroll view. This is a fix that
/// would die silently: a renamed class, nothing found, nothing changed, and the
/// bar back on top of somebody's message box with no line in any log. If a
/// future SDK renames it, that file goes red on the push which picks it up.
enum FormBar {
    /// What the class this makes is called: WebKit's own name, and this.
    private static let mark = "_QuietWithoutAFormBar"

    /// The name of the view that answers the keyboard's questions for a page.
    ///
    /// A prefix rather than the whole name, because the quietened class is
    /// still one of these and has to go on being found as one.
    private static let ownerName = "WKContentView"

    /// Where the nothing is kept, one per view it was asked of.
    ///
    /// A fresh view out of the getter each time would be a fresh view every
    /// time UIKit asks, which is often. An address allocated once and never
    /// freed is the ordinary way to key an associated object; it is one byte
    /// and it lives as long as the app.
    private static let keptHere = UnsafeRawPointer(
        UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    )

    /// The view inside a web view that owns the bar.
    ///
    /// It is there from the moment the web view is made — before a page, before
    /// a window — which is what lets this be done once, where the view is
    /// built, instead of watched for.
    @MainActor
    static func owner(of webView: WKWebView) -> UIView? {
        webView.scrollView.subviews.first {
            NSStringFromClass(type(of: $0)).hasPrefix(ownerName)
        }
    }

    /// Give every field on this web view's pages a bar that is nothing.
    ///
    /// Answers whether it found anything to do it to, so a test can tell a bar
    /// that is gone from a view that was never found. Saying it twice is free:
    /// the second call recognises its own work and leaves it alone.
    @MainActor
    @discardableResult
    static func take(from webView: WKWebView) -> Bool {
        guard let owner = owner(of: webView) else { return false }
        let current: AnyClass = type(of: owner)
        if NSStringFromClass(current).hasSuffix(mark) { return true }
        guard let quietened = quietened(current) else { return false }
        object_setClass(owner, quietened)
        return true
    }

    /// `original`, with `inputAccessoryView` answering with nothing.
    ///
    /// Made once for each class it is asked about and then found again by name.
    /// The Objective-C runtime is the register, so there is no table kept here
    /// and nothing two threads could race over.
    ///
    /// The method is copied off `UIResponder` for its signature only. What the
    /// getter of an object property is spelled like is not a thing to write out
    /// from memory while the runtime is holding the answer.
    private nonisolated static func quietened(_ original: AnyClass) -> AnyClass? {
        let name = NSStringFromClass(original) + mark
        if let already = NSClassFromString(name) { return already }

        let keptHere = self.keptHere
        let nothing: @convention(block) (AnyObject) -> UIView? = { owner in
            if let kept = objc_getAssociatedObject(owner, keptHere) as? UIView {
                return kept
            }
            // A `UIInputView` rather than a plain one, because that is what
            // UIKit puts in the strip above a keyboard and it is the shape
            // every measurement above was taken with. Zero points high, hidden,
            // and deaf to a finger: present for the arithmetic, absent from the
            // screen and from the reach of a thumb aiming at send.
            let made = UIInputView(frame: .zero, inputViewStyle: .keyboard)
            made.autoresizingMask = .flexibleWidth
            made.isUserInteractionEnabled = false
            made.isHidden = true
            objc_setAssociatedObject(
                owner, keptHere, made, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            return made
        }

        let asked = #selector(getter: UIResponder.inputAccessoryView)
        guard
            let inherited = class_getInstanceMethod(UIResponder.self, asked),
            let signature = method_getTypeEncoding(inherited),
            let made = objc_allocateClassPair(original, name, 0)
        else { return nil }

        class_addMethod(made, asked, imp_implementationWithBlock(nothing), signature)
        objc_registerClassPair(made)
        return made
    }
}
