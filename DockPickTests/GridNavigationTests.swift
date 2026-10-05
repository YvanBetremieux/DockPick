import XCTest
@testable import DockPick

final class GridNavigationTests: XCTestCase {
    let fiveRows = [3, 2]   // 0 1 2 / 3 4

    func testNoSelectionStartsAtFirstTile() {
        XCTAssertEqual(GridNavigation.move(from: nil, .right, rowCounts: fiveRows), 0)
        XCTAssertEqual(GridNavigation.move(from: 42, .down, rowCounts: fiveRows), 0)
    }

    func testEmptyGridHasNoSelection() {
        XCTAssertNil(GridNavigation.move(from: nil, .left, rowCounts: []))
    }

    func testHorizontalMovesAreClampedToTheList() {
        XCTAssertEqual(GridNavigation.move(from: 0, .left, rowCounts: fiveRows), 0)
        XCTAssertEqual(GridNavigation.move(from: 2, .right, rowCounts: fiveRows), 3)
        XCTAssertEqual(GridNavigation.move(from: 4, .right, rowCounts: fiveRows), 4)
    }

    func testVerticalMovesKeepColumnOrClamp() {
        XCTAssertEqual(GridNavigation.move(from: 0, .down, rowCounts: fiveRows), 3)
        XCTAssertEqual(GridNavigation.move(from: 2, .down, rowCounts: fiveRows), 4)
        XCTAssertEqual(GridNavigation.move(from: 4, .up, rowCounts: fiveRows), 1)
        XCTAssertEqual(GridNavigation.move(from: 1, .up, rowCounts: fiveRows), 1)
        XCTAssertEqual(GridNavigation.move(from: 3, .down, rowCounts: fiveRows), 3)
    }
}
