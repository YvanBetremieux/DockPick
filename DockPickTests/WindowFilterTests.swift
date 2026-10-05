import XCTest
@testable import DockPick

final class WindowFilterTests: XCTestCase {
    private func window(
        _ id: Int,
        title: String = "Fenêtre",
        subrole: String? = "AXStandardWindow",
        minimized: Bool = false,
        onSpace: Bool = true,
        size: CGSize = CGSize(width: 800, height: 600)
    ) -> WindowInfo {
        WindowInfo(id: id, windowID: CGWindowID(id), title: title, subrole: subrole,
                   isMinimized: minimized, isOnCurrentSpace: onSpace, frame: CGRect(origin: .zero, size: size))
    }

    private let all = WindowFilterOptions(includeMinimized: true, includeOtherSpaces: true)

    func testOnlyStandardWindowsAreKept() {
        let input = [
            window(1),
            window(2, subrole: "AXDialog"),
            window(3, subrole: "AXFloatingWindow"),
            window(4, subrole: nil),
        ]
        XCTAssertEqual(WindowFilter.filter(input, options: all).map(\.id), [1])
    }

    func testMinimizedWindowsFollowOption() {
        let input = [window(1), window(2, minimized: true, onSpace: false)]
        XCTAssertEqual(WindowFilter.filter(input, options: all).map(\.id), [1, 2])
        let noMinimized = WindowFilterOptions(includeMinimized: false, includeOtherSpaces: true)
        XCTAssertEqual(WindowFilter.filter(input, options: noMinimized).map(\.id), [1])
    }

    func testOtherSpaceWindowsFollowOption() {
        let input = [window(1), window(2, onSpace: false)]
        let currentOnly = WindowFilterOptions(includeMinimized: true, includeOtherSpaces: false)
        XCTAssertEqual(WindowFilter.filter(input, options: currentOnly).map(\.id), [1])
        XCTAssertEqual(WindowFilter.filter(input, options: all).map(\.id), [1, 2])
    }

    func testTinyWindowsAreDropped() {
        let input = [window(1), window(2, size: CGSize(width: 20, height: 20))]
        XCTAssertEqual(WindowFilter.filter(input, options: all).map(\.id), [1])
    }

    func testOrderIsPreserved() {
        let input = [window(3), window(1), window(2)]
        XCTAssertEqual(WindowFilter.filter(input, options: all).map(\.id), [3, 1, 2])
    }

    func testDisplayTitleUsesTrimmedTitle() {
        XCTAssertEqual(WindowFilter.displayTitle(for: window(1, title: "  Gmail  "), appName: "Chrome", index: 0), "Gmail")
    }

    func testDisplayTitleFallsBackWhenEmpty() {
        XCTAssertEqual(WindowFilter.displayTitle(for: window(1, title: ""), appName: "Chrome", index: 1), "Chrome — fenêtre 2")
        XCTAssertEqual(WindowFilter.displayTitle(for: window(1, title: " \n"), appName: "Chrome", index: 0), "Chrome — fenêtre 1")
    }
}
