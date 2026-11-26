import XCTest
@testable import Glaze

final class OneEuroFilterTests: XCTestCase {
    private func sample(_ x: CGFloat, _ y: CGFloat, t: TimeInterval, pressure: CGFloat = 1) -> InputPoint {
        InputPoint(location: CGPoint(x: x, y: y), pressure: pressure, timestamp: t)
    }

    func testFirstSamplePassesThroughExactly() {
        var filter = OneEuroFilter()
        let first = sample(12, 34, t: 1, pressure: 0.4)
        XCTAssertEqual(filter.filter(first), first)
    }

    func testSlowJitterIsSmoothed() {
        // A pointer held still with ±1 pt noise at 120 Hz.
        let raw = (0..<60).map { i in sample(100, 100 + (i % 2 == 0 ? 1 : -1), t: Double(i) / 120) }
        let out = OneEuroFilter.filter(all: raw)
        let rawSpread = raw.dropFirst(10).map { abs($0.location.y - 100) }.max()!
        let outSpread = out.dropFirst(10).map { abs($0.location.y - 100) }.max()!
        XCTAssertLessThan(outSpread, rawSpread * 0.5)
    }

    func testFastMotionFollowsClosely() {
        // 1000 pt/s straight line: lag stays small.
        let raw = (0..<60).map { i in sample(CGFloat(i) * 1000 / 120, 0, t: Double(i) / 120) }
        let out = OneEuroFilter.filter(all: raw)
        XCTAssertLessThan(abs(out.last!.location.x - raw.last!.location.x), 20)
    }

    func testPressureTiltAndTimestampPassThrough() {
        var filter = OneEuroFilter()
        _ = filter.filter(sample(0, 0, t: 0))
        var p = sample(10, 5, t: 0.01, pressure: 0.3)
        p.tilt = CGVector(dx: 0.2, dy: -0.4)
        let out = filter.filter(p)
        XCTAssertEqual(out.pressure, 0.3)
        XCTAssertEqual(out.tilt, p.tilt)
        XCTAssertEqual(out.timestamp, 0.01)
        XCTAssertNotEqual(out.location, p.location, "location is smoothed")
    }

    func testResetMakesNextSamplePassThrough() {
        var filter = OneEuroFilter()
        _ = filter.filter(sample(0, 0, t: 0))
        filter.reset()
        let p = sample(500, 500, t: 0.01)
        XCTAssertEqual(filter.filter(p), p)
    }
}

final class CatmullRomTests: XCTestCase {
    private func pts(_ xy: [(CGFloat, CGFloat)]) -> [InputPoint] {
        xy.map { InputPoint(location: CGPoint(x: $0.0, y: $0.1)) }
    }

    func testCurvePassesThroughEveryControl() {
        let controls = pts([(0, 0), (20, 10), (40, -5), (60, 30)])
        let result = CatmullRom.interpolate(controls)
        XCTAssertEqual(result.controlIndices.count, controls.count)
        for (control, index) in zip(controls, result.controlIndices) {
            XCTAssertEqual(result.points[index].location.x, control.location.x, accuracy: 1e-6)
            XCTAssertEqual(result.points[index].location.y, control.location.y, accuracy: 1e-6)
        }
        XCTAssertEqual(result.points.first?.location, controls.first?.location)
        XCTAssertEqual(result.points.last!.location.x, 60, accuracy: 1e-6)
    }

    func testSamplesRespectSpacing() {
        let result = CatmullRom.interpolate(pts([(0, 0), (50, 0), (100, 40)]), spacing: 2)
        for (a, b) in zip(result.points, result.points.dropFirst()) {
            XCTAssertLessThanOrEqual(hypot(b.location.x - a.location.x, b.location.y - a.location.y), 2.5)
        }
        XCTAssertGreaterThan(result.points.count, 50)
    }

    func testDuplicateControlsShareAnIndex() {
        let result = CatmullRom.interpolate(pts([(0, 0), (10, 0), (10, 0), (20, 0)]))
        XCTAssertEqual(result.controlIndices.count, 4)
        XCTAssertEqual(result.controlIndices[1], result.controlIndices[2])
        XCTAssertFalse(result.points.contains { $0.location.x.isNaN || $0.location.y.isNaN })
    }

    func testSinglePointAndEmpty() {
        let one = CatmullRom.interpolate(pts([(5, 5)]))
        XCTAssertEqual(one.points.map(\.location), [CGPoint(x: 5, y: 5)])
        XCTAssertEqual(one.controlIndices, [0])
        XCTAssertTrue(CatmullRom.interpolate([]).points.isEmpty)
    }

    func testPressureInterpolatesBetweenControls() {
        var controls = pts([(0, 0), (40, 0)])
        controls[0].pressure = 0
        controls[1].pressure = 1
        let result = CatmullRom.interpolate(controls)
        let pressures = result.points.map(\.pressure)
        XCTAssertEqual(pressures, pressures.sorted(), "pressure rises monotonically")
        XCTAssertEqual(pressures.first!, 0, accuracy: 1e-6)
        XCTAssertEqual(pressures.last!, 1, accuracy: 1e-6)
    }
}
