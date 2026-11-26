import XCTest
import KeyboardShortcuts
@testable import Glaze

final class ShortcutCatalogTests: XCTestCase {
    func testIDsAndNamesAreUnique() {
        let ids = ShortcutCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        let names = ShortcutCatalog.all.map(\.name.rawValue)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testEveryActionIsDescribed() {
        for a in ShortcutCatalog.all {
            XCTAssertFalse(a.title.isEmpty, a.id)
            XCTAssertFalse(a.detail.isEmpty, a.id)
        }
    }

    func testDefaultShortcutsDoNotCollide() {
        let defaults = ShortcutCatalog.all.compactMap(\.name.defaultShortcut)
        XCTAssertEqual(Set(defaults).count, defaults.count, "two actions share a default key")
    }

    func testGlobalDefaultsUseModifierKeys() {
        for a in ShortcutCatalog.actions(in: .global) {
            XCTAssertFalse(a.name.defaultShortcut?.modifiers.isEmpty ?? true, "\(a.id) would hijack typing")
        }
    }

    func testTheShortcutsPromisedInTheSpecExist() {
        for id in ["toggleDraw", "toggleLaser", "toggleNotepad", "toggleToolbar", "clearDisplay", "toolPen", "toolMarker",
                   "toolHighlighter", "toolEraser", "toolLaser", "sizeDown", "sizeUp", "eyedropper", "undo", "redo", "exitDraw"] {
            XCTAssertNotNil(ShortcutCatalog.action(id), id)
        }
        XCTAssertEqual((1...9).compactMap { ShortcutCatalog.action("colorSlot\($0)") }.count, 9)
    }

    func testUnknownActionIsNil() {
        XCTAssertNil(ShortcutCatalog.action("nope"))
    }

    func testEveryDrawingActionIsRegisteredWhileDrawingOnly() {
        // Drawing-scope actions are exactly the ones Hotkeys switches off outside Draw mode.
        XCTAssertFalse(ShortcutCatalog.actions(in: .drawing).isEmpty)
        XCTAssertTrue(Set(ShortcutCatalog.actions(in: .drawing).map(\.id)).isDisjoint(with: ShortcutCatalog.actions(in: .global).map(\.id)))
    }
}

final class HintTests: XCTestCase {
    func testPlainHintHasNoShortcutLine() {
        XCTAssertNil(Hint(title: "Move").shortcutLine)
    }

    func testActionHintTakesTitleDetailAndAShortcutLine() {
        let h = Hint(action: "toolPen")
        XCTAssertEqual(h.title, "Pen")
        XCTAssertNotNil(h.detail)
        XCTAssertNotNil(h.shortcutLine)
    }

    func testUnknownActionHasNoShortcutLine() {
        XCTAssertNil(Hint(title: "x", actionID: "nope").shortcutLine)
    }

    func testAnUnboundActionSaysSo() {
        // Pencil has no default key.
        let h = Hint(action: "toolPencil")
        XCTAssertEqual(h.shortcutLine, "No shortcut set")
    }
}

final class HintPlacementTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let size = CGSize(width: 200, height: 50)

    func testOpensBelowForATopDock() {
        let f = HintCenter.frame(for: size, near: CGPoint(x: 700, y: 800), edge: .top, in: screen)
        XCTAssertLessThan(f.maxY, 800)
    }

    func testOpensAboveForABottomDock() {
        let f = HintCenter.frame(for: size, near: CGPoint(x: 700, y: 60), edge: .bottom, in: screen)
        XCTAssertGreaterThan(f.minY, 60)
    }

    func testOpensToTheRightForALeftDockAndLeftForARightDock() {
        XCTAssertGreaterThan(HintCenter.frame(for: size, near: CGPoint(x: 40, y: 400), edge: .left, in: screen).minX, 40)
        XCTAssertLessThan(HintCenter.frame(for: size, near: CGPoint(x: 1400, y: 400), edge: .right, in: screen).maxX, 1400)
    }

    func testAlwaysStaysOnScreen() {
        for edge in [DockEdge?.none, .top, .bottom, .left, .right] {
            for p in [CGPoint(x: 2, y: 2), CGPoint(x: 1438, y: 898), CGPoint(x: 720, y: 450)] {
                let f = HintCenter.frame(for: size, near: p, edge: edge, in: screen)
                XCTAssertTrue(screen.contains(f), "\(String(describing: edge)) \(p) -> \(f)")
            }
        }
    }
}
