import CoreGraphics
import XCTest
@testable import DockPick

final class ClickPolicyTests: XCTestCase {
    private func context(enabled: Bool = true, excluded: Bool = false, windows: Int = 3, visible: Bool = false) -> ClickContext {
        ClickContext(enabled: enabled, isExcluded: excluded, windowCount: windows, pickerVisibleForThisApp: visible)
    }

    func testShowsPickerForTwoOrMoreWindows() {
        XCTAssertEqual(ClickPolicy.decide(context(windows: 2)), .showPicker)
        XCTAssertEqual(ClickPolicy.decide(context(windows: 6)), .showPicker)
    }

    func testPassesThroughForZeroOrOneWindow() {
        XCTAssertEqual(ClickPolicy.decide(context(windows: 0)), .passThrough)
        XCTAssertEqual(ClickPolicy.decide(context(windows: 1)), .passThrough)
    }

    func testPassesThroughWhenDisabledOrExcluded() {
        XCTAssertEqual(ClickPolicy.decide(context(enabled: false)), .passThrough)
        XCTAssertEqual(ClickPolicy.decide(context(excluded: true)), .passThrough)
    }

    func testClickingSameIconWhilePickerIsVisibleDismissesIt() {
        XCTAssertEqual(ClickPolicy.decide(context(windows: 0, visible: true)), .dismissPicker)
        XCTAssertEqual(ClickPolicy.decide(context(enabled: false, visible: true)), .dismissPicker)
    }

    func testPlainClick() {
        XCTAssertTrue(ClickPolicy.isPlainClick(flags: [], clickState: 1))
        XCTAssertTrue(ClickPolicy.isPlainClick(flags: [.maskAlphaShift, .maskNonCoalesced], clickState: 1))
    }

    func testModifiedOrRepeatedClicksAreNotPlain() {
        XCTAssertFalse(ClickPolicy.isPlainClick(flags: .maskCommand, clickState: 1))
        XCTAssertFalse(ClickPolicy.isPlainClick(flags: .maskAlternate, clickState: 1))
        XCTAssertFalse(ClickPolicy.isPlainClick(flags: .maskControl, clickState: 1))
        XCTAssertFalse(ClickPolicy.isPlainClick(flags: .maskShift, clickState: 1))
        XCTAssertFalse(ClickPolicy.isPlainClick(flags: [], clickState: 2))
    }
}
