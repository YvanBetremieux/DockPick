import XCTest
@testable import DockPick

final class SettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        suiteName = "DockPickTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaults() {
        let settings = Settings(defaults: defaults)
        XCTAssertTrue(settings.enabled)
        XCTAssertEqual(settings.openMode, .focus)
        XCTAssertEqual(settings.previewMode, .live)
        XCTAssertTrue(settings.includeMinimized)
        XCTAssertFalse(settings.includeOtherSpaces)
        XCTAssertEqual(settings.excludedBundleIDs, ["com.apple.finder"])
    }

    func testValuesPersistAcrossInstances() {
        let first = Settings(defaults: defaults)
        first.enabled = false
        first.openMode = .maximize
        first.previewMode = .titlesOnly
        first.includeMinimized = false
        first.includeOtherSpaces = true
        first.excludedBundleIDs = ["com.apple.Terminal"]

        let second = Settings(defaults: defaults)
        XCTAssertFalse(second.enabled)
        XCTAssertEqual(second.openMode, .maximize)
        XCTAssertEqual(second.previewMode, .titlesOnly)
        XCTAssertFalse(second.includeMinimized)
        XCTAssertTrue(second.includeOtherSpaces)
        XCTAssertEqual(second.excludedBundleIDs, ["com.apple.Terminal"])
    }

    func testUnknownStoredModeFallsBackToDefault() {
        defaults.set("bogus", forKey: Settings.Key.openMode)
        defaults.set("bogus", forKey: Settings.Key.previewMode)
        let settings = Settings(defaults: defaults)
        XCTAssertEqual(settings.openMode, .focus)
        XCTAssertEqual(settings.previewMode, .live)
    }

    func testIsExcluded() {
        let settings = Settings(defaults: defaults)
        XCTAssertTrue(settings.isExcluded("com.apple.finder"))
        XCTAssertFalse(settings.isExcluded("com.google.Chrome"))
        XCTAssertFalse(settings.isExcluded(nil))
    }

    func testSettingAValuePublishesChange() {
        let settings = Settings(defaults: defaults)
        var fired = false
        let cancellable = settings.objectWillChange.sink { fired = true }
        settings.enabled = false
        XCTAssertTrue(fired)
        cancellable.cancel()
    }
}
