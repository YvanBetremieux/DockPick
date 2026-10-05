import XCTest
@testable import DockPick

final class KeyCodesTests: XCTestCase {
    func testTopRowDigitsAreMappedByPhysicalKeyRegardlessOfLayout() {
        // Sur AZERTY ces touches produisent « & é " ' ( - è _ ç » sans Maj.
        let expected: [UInt16: Int] = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9]
        for (code, digit) in expected {
            XCTAssertEqual(KeyCodes.digit(for: code), digit, "keyCode \(code)")
        }
    }

    func testKeypadDigits() {
        let expected: [UInt16: Int] = [83: 1, 84: 2, 85: 3, 86: 4, 87: 5, 88: 6, 89: 7, 91: 8, 92: 9]
        for (code, digit) in expected {
            XCTAssertEqual(KeyCodes.digit(for: code), digit, "keyCode \(code)")
        }
    }

    func testOtherKeysAreNotDigits() {
        XCTAssertNil(KeyCodes.digit(for: 29))  // 0
        XCTAssertNil(KeyCodes.digit(for: 0))   // A/Q
        XCTAssertNil(KeyCodes.digit(for: 53))  // Échap
    }
}
