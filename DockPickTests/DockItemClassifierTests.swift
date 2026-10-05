import XCTest
@testable import DockPick

final class DockItemClassifierTests: XCTestCase {
    let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")

    func testApplicationItem() {
        XCTAssertEqual(
            DockItemClassifier.classify(role: "AXDockItem", subrole: "AXApplicationDockItem", url: chrome),
            .application(chrome.standardizedFileURL)
        )
    }

    func testNonApplicationItemsAreIgnored() {
        let downloads = URL(fileURLWithPath: "/Users/me/Downloads")
        XCTAssertEqual(DockItemClassifier.classify(role: "AXDockItem", subrole: "AXTrashDockItem", url: nil), .other)
        XCTAssertEqual(DockItemClassifier.classify(role: "AXDockItem", subrole: "AXFolderDockItem", url: downloads), .other)
        XCTAssertEqual(DockItemClassifier.classify(role: "AXDockItem", subrole: "AXMinimizedWindowDockItem", url: nil), .other)
        XCTAssertEqual(DockItemClassifier.classify(role: "AXDockItem", subrole: "AXSeparatorDockItem", url: nil), .other)
    }

    func testApplicationItemWithoutAppURLIsIgnored() {
        XCTAssertEqual(DockItemClassifier.classify(role: "AXDockItem", subrole: "AXApplicationDockItem", url: nil), .other)
        XCTAssertEqual(
            DockItemClassifier.classify(role: "AXDockItem", subrole: "AXApplicationDockItem", url: URL(fileURLWithPath: "/tmp/file.txt")),
            .other
        )
    }

    func testNonDockElementIsIgnored() {
        XCTAssertEqual(DockItemClassifier.classify(role: "AXList", subrole: nil, url: chrome), .other)
        XCTAssertEqual(DockItemClassifier.classify(role: nil, subrole: nil, url: nil), .other)
    }
}
