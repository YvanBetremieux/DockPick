import XCTest
@testable import DockPick

final class DockPressTrackerTests: XCTestCase {
    private let origin = CGPoint(x: 500, y: 1000)

    func testQuickClickOnInterceptedIconShowsPicker() {
        var tracker = DockPressTracker()
        XCTAssertEqual(tracker.mouseDown(intercept: true, time: 10, location: origin), .swallow)
        XCTAssertEqual(tracker.mouseUp(time: 10.15), .commit)
    }

    func testNotInterceptedPressPassesEverything() {
        var tracker = DockPressTracker()
        XCTAssertEqual(tracker.mouseDown(intercept: false, time: 10, location: origin), .pass)
        XCTAssertEqual(tracker.mouseDragged(location: CGPoint(x: 600, y: 1000)), .pass)
        XCTAssertEqual(tracker.mouseUp(time: 10.1), .pass)
    }

    func testSmallJitterDuringClickIsStillAClick() {
        var tracker = DockPressTracker()
        _ = tracker.mouseDown(intercept: true, time: 10, location: origin)
        XCTAssertEqual(tracker.mouseDragged(location: CGPoint(x: 502, y: 1001)), .swallow)
        XCTAssertEqual(tracker.mouseUp(time: 10.1), .commit)
    }

    func testDraggingTheIconReplaysThePressToTheDock() {
        var tracker = DockPressTracker()
        _ = tracker.mouseDown(intercept: true, time: 10, location: origin)
        XCTAssertEqual(tracker.mouseDragged(location: CGPoint(x: 520, y: 990)), .replayPressThenCurrent)
        XCTAssertEqual(tracker.mouseDragged(location: CGPoint(x: 560, y: 900)), .pass)
        XCTAssertEqual(tracker.mouseUp(time: 11), .pass)
    }

    func testLongHoldReplaysThePressSoTheDockShowsItsMenu() {
        var tracker = DockPressTracker()
        _ = tracker.mouseDown(intercept: true, time: 10, location: origin)
        XCTAssertEqual(tracker.holdTimerFired(time: 10.2), .none)
        XCTAssertEqual(tracker.holdTimerFired(time: 10.45), .replayPress)
        XCTAssertEqual(tracker.mouseUp(time: 11.5), .pass)
    }

    func testSlowReleaseWithoutTimerReplaysPressAndRelease() {
        var tracker = DockPressTracker()
        _ = tracker.mouseDown(intercept: true, time: 10, location: origin)
        XCTAssertEqual(tracker.mouseUp(time: 10.9), .replayPressThenCurrent)
    }

    func testTimerWithoutPendingPressDoesNothing() {
        var tracker = DockPressTracker()
        XCTAssertEqual(tracker.holdTimerFired(time: 99), .none)
        _ = tracker.mouseDown(intercept: true, time: 10, location: origin)
        _ = tracker.mouseUp(time: 10.1)
        XCTAssertEqual(tracker.holdTimerFired(time: 10.5), .none)
    }

    func testNewPressReplacesStalePendingPress() {
        var tracker = DockPressTracker()
        _ = tracker.mouseDown(intercept: true, time: 10, location: origin)
        XCTAssertEqual(tracker.mouseDown(intercept: false, time: 12, location: origin), .pass)
        XCTAssertEqual(tracker.mouseUp(time: 12.1), .pass)
    }
}
