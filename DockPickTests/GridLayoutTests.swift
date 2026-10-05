import XCTest
@testable import DockPick

final class GridLayoutTests: XCTestCase {
    let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)

    func testRowCounts() {
        XCTAssertEqual(GridLayout.rowCounts(for: 0), [])
        XCTAssertEqual(GridLayout.rowCounts(for: 1), [1])
        XCTAssertEqual(GridLayout.rowCounts(for: 2), [2])
        XCTAssertEqual(GridLayout.rowCounts(for: 3), [3])
        XCTAssertEqual(GridLayout.rowCounts(for: 4), [2, 2])
        XCTAssertEqual(GridLayout.rowCounts(for: 5), [3, 2])
        XCTAssertEqual(GridLayout.rowCounts(for: 6), [3, 3])
        XCTAssertEqual(GridLayout.rowCounts(for: 7), [4, 3])
        XCTAssertEqual(GridLayout.rowCounts(for: 9), [4, 4, 1])
    }

    func testFrameCountMatchesWindowCount() {
        for n in 0...9 {
            XCTAssertEqual(GridLayout.frames(count: n, in: screen).count, n, "n=\(n)")
        }
    }

    func testFramesStayInsideMarginsAndNeverOverlap() {
        let area = screen.insetBy(dx: 48, dy: 48).insetBy(dx: -0.001, dy: -0.001)
        for n in 1...9 {
            let frames = GridLayout.frames(count: n, in: screen)
            for frame in frames {
                XCTAssertTrue(area.contains(frame), "n=\(n) \(frame)")
            }
            for i in frames.indices {
                for j in frames.indices where j > i {
                    XCTAssertFalse(frames[i].insetBy(dx: 0.5, dy: 0.5).intersects(frames[j]), "n=\(n) \(i)/\(j)")
                }
            }
        }
    }

    func testTwoWindowsAreSideBySide() {
        let f = GridLayout.frames(count: 2, in: screen)
        XCTAssertEqual(f[0].minY, f[1].minY)
        XCTAssertEqual(f[0].size, f[1].size)
        XCTAssertEqual(f[1].minX - f[0].maxX, 24, accuracy: 0.001)
        XCTAssertEqual(f[0].minX, 48, accuracy: 0.001)
        XCTAssertEqual(f[1].maxX, 1552, accuracy: 0.001)
    }

    func testFourWindowsFormQuadrants() {
        let f = GridLayout.frames(count: 4, in: screen)
        XCTAssertEqual(f[0].minY, f[1].minY)
        XCTAssertEqual(f[2].minY, f[3].minY)
        XCTAssertEqual(f[0].minX, f[2].minX)
        XCTAssertEqual(f[1].minX, f[3].minX)
        XCTAssertGreaterThan(f[2].minY, f[0].maxY)
        XCTAssertTrue(f.allSatisfy { $0.size == f[0].size })
    }

    func testFiveWindowsBottomRowIsCenteredWithSameTileSize() {
        let f = GridLayout.frames(count: 5, in: screen)
        XCTAssertEqual(f[3].size, f[0].size)
        let topCenter = (f[0].minX + f[2].maxX) / 2
        let bottomCenter = (f[3].minX + f[4].maxX) / 2
        XCTAssertEqual(topCenter, bottomCenter, accuracy: 0.001)
        XCTAssertGreaterThan(f[3].minY, f[0].maxY)
    }

    func testContainerOriginIsRespected() {
        let f = GridLayout.frames(count: 2, in: CGRect(x: 100, y: 200, width: 1600, height: 1000))
        XCTAssertEqual(f[0].minX, 148, accuracy: 0.001)
        XCTAssertEqual(f[0].minY, 248, accuracy: 0.001)
    }

    func testTooSmallContainerYieldsNoFrames() {
        XCTAssertEqual(GridLayout.frames(count: 3, in: CGRect(x: 0, y: 0, width: 80, height: 80)), [])
    }
}

final class GridHitTestTests: XCTestCase {
    func testIndexAtPointFindsTile() {
        let frames = GridLayout.frames(count: 4, in: CGRect(x: 0, y: 0, width: 1600, height: 1000))
        XCTAssertEqual(GridLayout.index(at: CGPoint(x: frames[3].midX, y: frames[3].midY), in: frames), 3)
        XCTAssertEqual(GridLayout.index(at: CGPoint(x: frames[0].minX + 1, y: frames[0].minY + 1), in: frames), 0)
    }

    func testIndexAtPointInGapOrMarginIsNil() {
        let frames = GridLayout.frames(count: 2, in: CGRect(x: 0, y: 0, width: 1600, height: 1000))
        XCTAssertNil(GridLayout.index(at: CGPoint(x: 10, y: 10), in: frames))
        XCTAssertNil(GridLayout.index(at: CGPoint(x: (frames[0].maxX + frames[1].minX) / 2, y: frames[0].midY), in: frames))
    }
}
