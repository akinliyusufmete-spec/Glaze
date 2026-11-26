import Foundation

/// Identifies a drawing tool. Phase 1 only uses `.pen`; the rest are placeholders
/// so `AppMode` has its final shape from the start.
// DECISION: ToolID lives in Core (not Tools) because AppMode needs it and the
// dependency rule says Core imports nothing from the other folders.
enum ToolID: String, CaseIterable, Hashable, Codable, Sendable {
    case pen, marker, highlighter, pencil, calligraphy, neon, dashed, eraser
    case rectangle, ellipse, arrow, line, image, laser

    var displayName: String { rawValue.capitalized }
}
