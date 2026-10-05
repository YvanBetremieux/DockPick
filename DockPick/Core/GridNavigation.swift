enum MoveDirection {
    case left, right, up, down
}

enum GridNavigation {
    /// Nouvel index sélectionné après un appui sur une flèche.
    static func move(from index: Int?, _ direction: MoveDirection, rowCounts: [Int]) -> Int? {
        let count = rowCounts.reduce(0, +)
        guard count > 0 else { return nil }
        guard let index, (0..<count).contains(index) else { return 0 }

        var row = 0
        var rowStart = 0
        while index >= rowStart + rowCounts[row] {
            rowStart += rowCounts[row]
            row += 1
        }
        let column = index - rowStart

        switch direction {
        case .left:
            return max(0, index - 1)
        case .right:
            return min(count - 1, index + 1)
        case .up:
            guard row > 0 else { return index }
            let previousStart = rowStart - rowCounts[row - 1]
            return previousStart + min(column, rowCounts[row - 1] - 1)
        case .down:
            guard row < rowCounts.count - 1 else { return index }
            let nextStart = rowStart + rowCounts[row]
            return nextStart + min(column, rowCounts[row + 1] - 1)
        }
    }
}
