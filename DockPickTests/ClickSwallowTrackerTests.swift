import XCTest
@testable import DockPick

final class ClickSwallowTrackerTests: XCTestCase {
    func testSwallowedDownSwallowsExactlyOneUp() {
        var tracker = ClickSwallowTracker()
        tracker.mouseDown(swallowed: true)
        XCTAssertTrue(tracker.shouldSwallowMouseUp())
        XCTAssertFalse(tracker.shouldSwallowMouseUp())
    }

    func testPassedDownNeverSwallowsUp() {
        var tracker = ClickSwallowTracker()
        tracker.mouseDown(swallowed: false)
        XCTAssertFalse(tracker.shouldSwallowMouseUp())
    }

    func testUpWithoutDownIsNotSwallowed() {
        var tracker = ClickSwallowTracker()
        XCTAssertFalse(tracker.shouldSwallowMouseUp())
    }

    func testLaterPassedDownResetsPendingSwallow() {
        var tracker = ClickSwallowTracker()
        tracker.mouseDown(swallowed: true)
        tracker.mouseDown(swallowed: false)
        XCTAssertFalse(tracker.shouldSwallowMouseUp())
    }
}
