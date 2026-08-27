import Foundation

/// iCloud, holding one small object where this phone's other phones can see it.
///
/// **Why the key-value store and not CloudKit's database.** Both are iCloud and
/// both would work. A `CKRecord` needs a container and a schema, and a schema
/// has to be pushed from development to production by hand in a console on a
/// desktop browser before a TestFlight build can write a single field. Until
/// somebody does that, the feature is silently dead on every phone that has it
/// — and there is no way to tell from the phone. The key-value store needs an
/// entitlement and nothing else: no container to pick, no record type, no
/// deployment step, and no way for it to be half set up.
///
/// What it costs is size, and the cost is not real here. A megabyte in total;
/// this writes a few hundred bytes — a limit, a wait, a date and a handful of
/// running totals.
///
/// Nothing here decides anything. Every question about what happens when the
/// two copies disagree is answered in `Carried.merge`, which is a pure function
/// with its own tests, because that is where somebody would come looking.
@MainActor
final class CloudMirror: Cloud {
    private let store: NSUbiquitousKeyValueStore
    private static let key = "quiet.carried"

    init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
        // Asks iCloud for anything newer than what is on disk. The answer
        // arrives later and by itself; this only starts it off, so the copy
        // read a moment from now is as fresh as the network has managed.
        store.synchronize()
    }

    func fetch() async -> Carried? {
        guard let data = store.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(Carried.self, from: data)
    }

    func put(_ carried: Carried) async {
        guard let data = try? JSONEncoder().encode(carried) else { return }
        store.set(data, forKey: Self.key)
        store.synchronize()
    }

    func forget() async {
        store.removeObject(forKey: Self.key)
        store.synchronize()
    }
}
