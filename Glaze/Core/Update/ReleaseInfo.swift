import Foundation

/// The parts of a GitHub release the update check cares about.
struct ReleaseInfo: Equatable, Sendable {
    enum ParseError: Error, Equatable { case malformed, notAVersion(String) }

    let version: SemanticVersion
    let tag: String
    /// The release's web page (always present).
    let pageURL: URL
    /// Direct link to the `.dmg` (or else `.zip`) asset, when the release has one.
    let downloadURL: URL?
    let notes: String

    /// Parses the JSON of `GET /repos/{owner}/{repo}/releases/latest`.
    static func parse(_ data: Data) throws -> ReleaseInfo {
        struct Asset: Decodable { let name: String; let browser_download_url: String }
        struct Payload: Decodable {
            let tag_name: String
            let html_url: String
            let body: String?
            let assets: [Asset]?
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let page = URL(string: payload.html_url) else { throw ParseError.malformed }
        guard let version = SemanticVersion(payload.tag_name) else { throw ParseError.notAVersion(payload.tag_name) }

        let assets = payload.assets ?? []
        let chosen = assets.first { $0.name.lowercased().hasSuffix(".dmg") }
            ?? assets.first { $0.name.lowercased().hasSuffix(".zip") }
        return ReleaseInfo(
            version: version,
            tag: payload.tag_name,
            pageURL: page,
            downloadURL: chosen.flatMap { URL(string: $0.browser_download_url) },
            notes: payload.body ?? ""
        )
    }
}
