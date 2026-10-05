import XCTest
@testable import DockPick

final class ScreenGeometryTests: XCTestCase {
    // Écran principal 1440×900 ; écran secondaire 1920×1080 à gauche, décalé de 200 pt vers le bas.
    let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let secondary = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
    let primaryHeight: CGFloat = 900

    func testPointConversion() {
        XCTAssertEqual(ScreenGeometry.cocoaPoint(fromAX: CGPoint(x: 10, y: 0), primaryScreenHeight: primaryHeight), CGPoint(x: 10, y: 900))
        XCTAssertEqual(ScreenGeometry.cocoaPoint(fromAX: CGPoint(x: -100, y: 1000), primaryScreenHeight: primaryHeight), CGPoint(x: -100, y: -100))
    }

    func testRectRoundTrip() {
        let ax = CGRect(x: -1900, y: 300, width: 800, height: 500)
        let cocoa = ScreenGeometry.cocoaRect(fromAX: ax, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(cocoa, CGRect(x: -1900, y: 100, width: 800, height: 500))
        XCTAssertEqual(ScreenGeometry.axRect(fromCocoa: cocoa, primaryScreenHeight: primaryHeight), ax)
    }

    func testVisibleFrameOfSecondaryScreenMapsToAXTopLeft() {
        let ax = ScreenGeometry.axRect(fromCocoa: secondary, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(ax, CGRect(x: -1920, y: 20, width: 1920, height: 1080))
    }

    func testScreenIndexForDockClickAtBottomOfSecondaryScreen() {
        // Clic sur le Dock en bas de l'écran secondaire : y AX = 1099 → y Cocoa = -199.
        let cocoa = ScreenGeometry.cocoaPoint(fromAX: CGPoint(x: -960, y: 1099), primaryScreenHeight: primaryHeight)
        XCTAssertEqual(ScreenGeometry.screenIndex(containing: cocoa, screenFrames: [primary, secondary]), 1)
    }

    func testScreenIndexForPrimaryAndOutside() {
        XCTAssertEqual(ScreenGeometry.screenIndex(containing: CGPoint(x: 700, y: 1), screenFrames: [primary, secondary]), 0)
        XCTAssertNil(ScreenGeometry.screenIndex(containing: CGPoint(x: 5000, y: 5000), screenFrames: [primary, secondary]))
    }
}
