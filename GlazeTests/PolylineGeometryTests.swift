import XCTest
@testable import Glaze

final class PolylineGeometryTests: XCTestCase {
    private let a = CGPoint(x: 0, y: 0)
    private let b = CGPoint(x: 10, y: 0)

    func testDistanceToSegmentInteriorIsPerpendicular() {
        XCTAssertEqual(PolylineGeometry.distance(from: CGPoint(x: 5, y: 3), toSegment: a, b), 3, accuracy: 1e-9)
    }

    func testDistanceToSegmentClampsToEndpoints() {
        XCTAssertEqual(PolylineGeometry.distance(from: CGPoint(x: -3, y: 4), toSegment: a, b), 5, accuracy: 1e-9)
        XCTAssertEqual(PolylineGeometry.distance(from: CGPoint(x: 13, y: 4), toSegment: a, b), 5, accuracy: 1e-9)
    }

    func testDistanceToDegenerateSegmentIsPointDistance() {
        XCTAssertEqual(PolylineGeometry.distance(from: CGPoint(x: 3, y: 4), toSegment: a, a), 5, accuracy: 1e-9)
    }

    func testDistanceToPolylineTakesNearestSegment() {
        let polyline = [a, b, CGPoint(x: 10, y: 10)]
        XCTAssertEqual(PolylineGeometry.distance(from: CGPoint(x: 12, y: 5), toPolyline: polyline), 2, accuracy: 1e-9)
    }

    func testDistanceToSinglePointPolyline() {
        XCTAssertEqual(PolylineGeometry.distance(from: CGPoint(x: 0, y: 2), toPolyline: [a]), 2, accuracy: 1e-9)
    }

    func testDistanceToEmptyPolylineIsInfinite() {
        XCTAssertEqual(PolylineGeometry.distance(from: a, toPolyline: []), .infinity)
    }

    func testBoundingRect() {
        let rect = PolylineGeometry.boundingRect(of: [CGPoint(x: 3, y: -2), CGPoint(x: -1, y: 5), CGPoint(x: 2, y: 1)])
        XCTAssertEqual(rect, CGRect(x: -1, y: -2, width: 4, height: 7))
        XCTAssertTrue(PolylineGeometry.boundingRect(of: []).isNull)
    }

    func testSamplesIncludeEndpointsAndRespectSpacing() {
        let samples = PolylineGeometry.samples(from: a, to: b, spacing: 3)
        XCTAssertEqual(samples.first, a)
        XCTAssertEqual(samples.last, b)
        XCTAssertEqual(samples.count, 5) // ceil(10 / 3) = 4 steps
        for (p, q) in zip(samples, samples.dropFirst()) {
            XCTAssertLessThanOrEqual(hypot(q.x - p.x, q.y - p.y), 3 + 1e-9)
        }
    }

    func testSamplesForZeroLengthSegment() {
        XCTAssertEqual(PolylineGeometry.samples(from: a, to: a, spacing: 2), [a, a])
    }
}
