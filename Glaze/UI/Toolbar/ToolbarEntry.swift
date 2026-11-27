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
    /// One line explaining what the button does; shown in its hover hint.
    let detail: String
    /// Preferred SF Symbol name.
    let symbol: String
    /// Used when `symbol` doesn't exist on the running macOS version.
    let fallbackSymbol: String?
    /// Id of the `ShortcutCatalog` action whose keybinding the hint shows.
    let shortcutAction: String?

    init(id: String, kind: Kind = .tool, title: String, detail: String = "", symbol: String,
         fallbackSymbol: String? = nil, shortcutAction: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.fallbackSymbol = fallbackSymbol
        self.shortcutAction = shortcutAction
    }

    static func separator(_ id: String) -> ToolbarEntry {
        ToolbarEntry(id: id, kind: .separator, title: "", symbol: "")
    }

    /// The hover hint: name, explanation and the live keybinding.
    var hint: Hint { Hint(title: title, detail: detail.isEmpty ? nil : detail, actionID: shortcutAction) }

    /// First symbol name that exists on this system, else `nil`.
    var resolvedSymbol: String? {
        for name in [symbol, fallbackSymbol].compactMap({ $0 }) where !name.isEmpty {
            if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil { return name }
        }
        return nil
    }
}
