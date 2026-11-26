import AppKit

/// One item in the floating toolbar. Decoupled from the tool registry: `id` is whatever
/// identifier the app uses for the tool (or action).
struct ToolbarEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case tool       // selectable; one is active at a time
        case action     // fire-and-forget (undo, clear, ...)
        case separator
    }

    let id: String
    let kind: Kind
    let title: String
    /// Preferred SF Symbol name.
    let symbol: String
    /// Used when `symbol` doesn't exist on the running macOS version.
    let fallbackSymbol: String?
    /// Shown in the tooltip, e.g. "P".
    let shortcutHint: String?

    init(id: String, kind: Kind = .tool, title: String, symbol: String,
         fallbackSymbol: String? = nil, shortcutHint: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.symbol = symbol
        self.fallbackSymbol = fallbackSymbol
        self.shortcutHint = shortcutHint
    }

    static func separator(_ id: String) -> ToolbarEntry {
        ToolbarEntry(id: id, kind: .separator, title: "", symbol: "")
    }

    var tooltip: String {
        guard let hint = shortcutHint, !hint.isEmpty else { return title }
        return "\(title) (\(hint))"
    }

    /// First symbol name that exists on this system, else `nil`.
    var resolvedSymbol: String? {
        for name in [symbol, fallbackSymbol].compactMap({ $0 }) where !name.isEmpty {
            if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil { return name }
        }
        return nil
    }
}
