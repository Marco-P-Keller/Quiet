import XCTest
@testable import Quiet

/// The second lock, checked against the first.
///
/// Three copies of the same table now exist: `ContentRules.blockedRoots` in
/// Swift, `ROOT_SURFACE` in trim.js, and the alternation inside `BlockList`.
/// Three copies of a rule are three rules, and the day they disagree the one
/// that is wrong is silently the one that matters — so the agreement is a test
/// rather than an intention.
final class BlockListTests: XCTestCase {
    func testTheRulesAreValidJSONInTheShapeWebKitWants() throws {
        let data = try XCTUnwrap(BlockList.rules.data(using: .utf8))
        let parsed = try JSONSerialization.jsonObject(with: data)
        let rules = try XCTUnwrap(parsed as? [[String: Any]])
        XCTAssertFalse(rules.isEmpty)

        for rule in rules {
            let trigger = try XCTUnwrap(rule["trigger"] as? [String: Any])
            XCTAssertNotNil(trigger["url-filter"] as? String)
            XCTAssertEqual(trigger["resource-type"] as? [String], ["document", "raw"])
            XCTAssertEqual(
                (rule["action"] as? [String: Any])?["type"] as? String,
                "block"
            )
        }
    }

    /// Every root the app refuses by address is a root the block list refuses
    /// too. Written as a loop over the Swift table so that adding a root there
    /// and forgetting this file is a red line rather than a quiet hole.
    func testEveryBlockedRootIsInTheList() throws {
        for root in ContentRules.blockedRoots.keys {
            let address = "https://www.instagram.com/\(root)/"
            XCTAssertTrue(
                matches(address),
                "\(address) is refused by ContentRules and not by the block list"
            )
        }
    }

    func testTheAddressesTheAppRefusesAreRefusedHereToo() throws {
        for address in [
            "https://www.instagram.com/reels/",
            "https://www.instagram.com/reel/CxYz123/",
            "https://www.instagram.com/tv/CxYz123/",
            "https://www.instagram.com/explore/tags/sunset/",
            "https://www.instagram.com/directory/profiles/",
            "https://www.instagram.com/accounts/suggested/",
            "https://www.instagram.com/someone/reels/",
            "https://i.instagram.com/explore/",
            "http://instagram.com/reels/",
        ] {
            XCTAssertTrue(matches(address), address)
        }
    }

    /// The half that matters more. A rule that is one address too wide is a
    /// feed with holes in it, and a hole is harder to notice than a door.
    func testEverythingElseIsLeftAlone() throws {
        for address in [
            "https://www.instagram.com/",
            "https://www.instagram.com/someone/",
            "https://www.instagram.com/reelstuff/",
            "https://www.instagram.com/tvtotal/",
            "https://www.instagram.com/explorers/",
            "https://www.instagram.com/p/CxYz123/",
            "https://www.instagram.com/stories/someone/123/",
            "https://www.instagram.com/direct/inbox/",
            "https://www.instagram.com/accounts/login/",
            "https://www.instagram.com/accounts/edit/",
            // The search the panel runs, which must keep working.
            "https://www.instagram.com/api/v1/web/search/topsearch/?query=x",
            // Somebody else's site, which is Safari's business and not this
            // list's.
            "https://example.com/explore/",
            // And a host that merely ends with the same letters.
            "https://notinstagram.com/reels/",
        ] {
            XCTAssertFalse(matches(address), address)
        }
    }

    /// The regular expressions are also read out of the serialised document
    /// rather than from `filters` directly, so that a document which cannot be
    /// parsed fails every one of these rather than only the first.
    ///
    /// WebKit compiles `url-filter` with its own engine, not this one. The
    /// syntax used here — anchors, character classes, groups, alternation — is
    /// the subset both understand, which is what makes the two comparable at
    /// all. Anything cleverer than that would make this test a fiction.
    private func matches(_ address: String) -> Bool {
        guard let data = BlockList.rules.data(using: .utf8),
              let rules = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            XCTFail("the rules are not a document anything can read")
            return false
        }
        return rules.contains { rule in
            guard let trigger = rule["trigger"] as? [String: Any],
                  let filter = trigger["url-filter"] as? String,
                  let expression = try? NSRegularExpression(
                      pattern: filter,
                      options: [.caseInsensitive]
                  )
            else {
                XCTFail("a rule has no readable filter")
                return false
            }
            let whole = NSRange(address.startIndex..., in: address)
            return expression.firstMatch(in: address, range: whole) != nil
        }
    }
}
