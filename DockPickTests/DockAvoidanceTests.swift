import XCTest
@testable import DockPick

final class DockAvoidanceTests: XCTestCase {
    // Cocoa : écran 1512×982, barre de menus 33 pt, Dock masqué automatiquement (visibleFrame = presque tout l'écran).
    let visible = CGRect(x: 0, y: 0, width: 1512, height: 949)

    func testBottomDockRaisesTheBottomEdge() {
        let dock = CGRect(x: 300, y: 0, width: 900, height: 80)
        XCTAssertEqual(DockAvoidance.usableFrame(visibleFrame: visible, dockFrames: [dock]), CGRect(x: 0, y: 80, width: 1512, height: 869))
    }

    func testLeftDockMovesTheLeftEdge() {
        let dock = CGRect(x: 0, y: 200, width: 70, height: 500)
        XCTAssertEqual(DockAvoidance.usableFrame(visibleFrame: visible, dockFrames: [dock]), CGRect(x: 70, y: 0, width: 1442, height: 949))
    }

    func testRightDockMovesTheRightEdge() {
        let dock = CGRect(x: 1442, y: 200, width: 70, height: 500)
        XCTAssertEqual(DockAvoidance.usableFrame(visibleFrame: visible, dockFrames: [dock]), CGRect(x: 0, y: 0, width: 1442, height: 949))
    }

    func testDockOnAnotherScreenIsIgnored() {
        let dock = CGRect(x: -1500, y: 0, width: 900, height: 80)
        XCTAssertEqual(DockAvoidance.usableFrame(visibleFrame: visible, dockFrames: [dock]), visible)
    }

    func testHugeDockWindowIsIgnored() {
        // Le Dock possède aussi des fenêtres plein écran transparentes : elles ne doivent pas vider la zone.
        XCTAssertEqual(DockAvoidance.usableFrame(visibleFrame: visible, dockFrames: [visible]), visible)
    }

    func testNoDockKeepsVisibleFrame() {
        XCTAssertEqual(DockAvoidance.usableFrame(visibleFrame: visible, dockFrames: []), visible)
    }
}
