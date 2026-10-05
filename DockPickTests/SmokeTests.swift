import XCTest
@testable import DockPick

final class SmokeTests: XCTestCase {
    func testHostAppBundleIdentifier() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "io.github.yvanbetremieux.DockPick")
    }

    func testRunningTestsIsDetected() {
        XCTAssertTrue(AppDelegate.isRunningTests)
    }
}
