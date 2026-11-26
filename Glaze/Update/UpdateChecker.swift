import Foundation
import Observation

/// Checks GitHub Releases for a newer version. It only reads the public "latest release"
/// endpoint and sends nothing about the user or the machine.
// DECISION: a lightweight check that opens the release page, not an in-place updater. Silent
// updates (Sparkle) need an EdDSA signing key kept in CI secrets; that can be added later
// without changing this type's callers.
@MainActor
@Observable
final class UpdateChecker {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case failed(String)
    }

    static let repository = "akinliyusufmete-spec/Glaze"
    /// How long to wait between automatic checks.
    static let interval: TimeInterval = 24 * 60 * 60

    private(set) var state: State = .idle
    let currentVersion: SemanticVersion

    @ObservationIgnored private let fetch: @Sendable () async throws -> Data
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date

    private static let lastCheckKey = "lastUpdateCheck"

    init(
        currentVersion: SemanticVersion,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        fetch: @escaping @Sendable () async throws -> Data = UpdateChecker.fetchLatestRelease
    ) {
        self.currentVersion = currentVersion
        self.defaults = defaults
        self.now = now
        self.fetch = fetch
    }

    /// The running app's version, from its Info.plist (`MARKETING_VERSION`).
    static func bundleVersion(_ bundle: Bundle = .main) -> SemanticVersion {
        let text = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        return text.flatMap(SemanticVersion.init) ?? SemanticVersion("0.0.0")!
    }

    /// Checks now, whatever the schedule says.
    func check() async {
        guard state != .checking else { return }
        state = .checking
        defaults.set(now(), forKey: Self.lastCheckKey)
        do {
            let release = try ReleaseInfo.parse(await fetch())
            state = release.version > currentVersion ? .available(release) : .upToDate
        } catch let error as UpdateError where error == .noReleases {
            state = .upToDate
        } catch {
            state = .failed(Self.describe(error))
        }
    }

    /// Checks only if the last check was more than `interval` ago. Used at launch.
    func checkIfDue() async {
        if let last = defaults.object(forKey: Self.lastCheckKey) as? Date,
           now().timeIntervalSince(last) < Self.interval { return }
        await check()
    }

    // MARK: Networking

    enum UpdateError: Error, Equatable {
        case noReleases
        case http(Int)
    }

    nonisolated static func fetchLatestRelease() async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Glaze-update-check", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { throw UpdateError.noReleases }      // no release published yet
        guard status == 200 else { throw UpdateError.http(status) }
        return data
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case let UpdateError.http(code): "GitHub returned HTTP \(code)"
        case is ReleaseInfo.ParseError: "Couldn't read the latest release"
        default: error.localizedDescription
        }
    }
}
