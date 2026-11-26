import XCTest
@testable import Glaze

final class NoteStrokeRecordTests: XCTestCase {
    private func stroke() -> StrokeElement {
        let samples = [
            InputPoint(location: CGPoint(x: 1, y: 2), pressure: 0.4, tilt: CGVector(dx: 0.1, dy: -0.2), timestamp: 5),
            InputPoint(location: CGPoint(x: 30, y: 40), pressure: 0.9, tilt: .zero, timestamp: 6),
            InputPoint(location: CGPoint(x: 60, y: 10), pressure: 1, tilt: .zero, timestamp: 7),
        ]
        return StrokeElement(
            samples: samples, style: BrushPresets.marker,
            color: RGBAColor(r: 0.2, g: 0.4, b: 0.6, a: 0.8).cgColor,
            transform: CGAffineTransform(translationX: 3, y: 4)
        )
    }

    func testRoundTripKeepsEverything() throws {
        let original = stroke()
        let record = NoteStrokeRecord(original)
        let restored = record.makeStroke()
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.samples, original.samples)
        XCTAssertEqual(restored.style, original.style)
        XCTAssertEqual(restored.transform, original.transform)
        let c = RGBAColor(restored.color)
        XCTAssertEqual(Double(c.r), 0.2, accuracy: 0.002)
        XCTAssertEqual(Double(c.a), 0.8, accuracy: 0.002)
    }

    func testSurvivesJSON() throws {
        let record = NoteStrokeRecord(stroke())
        let decoded = try JSONDecoder().decode(NoteStrokeRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded, record)
    }

    func testBadTransformFallsBackToIdentity() {
        var record = NoteStrokeRecord(stroke())
        record.transform = [1, 2]
        XCTAssertEqual(record.makeStroke().transform, .identity)
    }
}
