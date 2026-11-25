import AppKit

/// Samples a pixel anywhere on screen (including other apps) with the system magnifier.
@MainActor
final class Eyedropper {
    private var sampler: NSColorSampler?     // must stay alive while the loupe is up

    var isActive: Bool { sampler != nil }

    /// `completion` receives `nil` if the user cancelled (Escape).
    func pick(completion: @escaping (RGBAColor?) -> Void) {
        guard sampler == nil else { return }
        let s = NSColorSampler()
        sampler = s
        s.show { [weak self] nsColor in
            self?.sampler = nil
            completion(nsColor.flatMap { RGBAColor(nsColor: $0) })
        }
    }
}
