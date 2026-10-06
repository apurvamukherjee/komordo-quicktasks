import Foundation
import Network

/// Whether the Mac has a way out to the internet (ARCHITECTURE §4.4: offline, wait until the network is back, then
/// catch up). Everything on the Board works without one; only the task tools and Claude ask.
@MainActor @Observable final class Connectivity {
    static let shared = Connectivity()
    /// Posted on the main queue when the network comes back, so anything that waited can catch up.
    static let backOnline = Notification.Name("app.komodo.back-online")

    private(set) var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()

    private init() {
        #if DEBUG
            // `-offline YES` stands in for a Mac with no network, for captures and tries of the offline states.
            if UserDefaults.standard.bool(forKey: "offline") {
                isOnline = false
                return
            }
        #endif
        monitor.pathUpdateHandler = { path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in Connectivity.shared.update(isOnline) }
        }
        monitor.start(queue: DispatchQueue(label: "app.komodo.connectivity", qos: .utility))
    }

    private func update(_ isOnline: Bool) {
        guard isOnline != self.isOnline else { return }
        self.isOnline = isOnline
        if isOnline { NotificationCenter.default.post(name: Self.backOnline, object: nil) }
    }
}
