import XCTest
@testable import Glaze

final class BrushPresetsTests: XCTestCase {
    func testEveryPresetRoundTripsThroughCodable() throws {
        for style in BrushPresets.all {
            let data = try JSONEncoder().encode(style)
            XCTAssertEqual(try JSONDecoder().decode(BrushStyle.self, from: data), style, style.name)
        }
    }

    func testPresetsArePairwiseDistinct() {
        XCTAssertEqual(BrushPresets.all.count, 8)
        XCTAssertEqual(Set(BrushPresets.all).count, BrushPresets.all.count)
        XCTAssertEqual(Set(BrushPresets.all.map(\.name)).count, BrushPresets.all.count)
    }

    func testOnlyTheLaserIsTransient() {
        XCTAssertEqual(BrushPresets.all.filter(\.isTransient).map(\.name), [BrushPresets.laser.name])
        XCTAssertNotNil(BrushPresets.laser.fadeDuration)
    }

    func testHighlighterMultiplies() {
        XCTAssertEqual(BrushPresets.highlighter.blendMode, .multiply)
        XCTAssertLessThan(BrushPresets.highlighter.opacity, 1)
        XCTAssertTrue(BrushPresets.highlighter.autoStraighten)
    }

    func testNonBrushToolsHaveNoPreset() {
        XCTAssertNil(BrushPresets.preset(for: .eraser))
        XCTAssertNil(BrushPresets.preset(for: .rectangle))
        XCTAssertEqual(BrushPresets.preset(for: .laser), BrushPresets.laser)
    }

    func testEveryRegisteredBrushHasAPreset() {
        for id in ToolRegistry.brushIDs {
            XCTAssertNotNil(BrushPresets.preset(for: id), "\(id)")
        }
    }

    func testUniformStyleIsUniform() {
        XCTAssertTrue(BrushPresets.uniform(width: 4).isUniformWidth)
        XCTAssertFalse(BrushPresets.pen.isUniformWidth)
        XCTAssertFalse(BrushPresets.calligraphy.isUniformWidth)
    }
}
