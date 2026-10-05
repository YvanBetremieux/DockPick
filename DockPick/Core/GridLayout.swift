import CoreGraphics

enum GridLayout {
    /// Nombre de cases par ligne, de haut en bas.
    static func rowCounts(for count: Int) -> [Int] {
        switch count {
        case ..<1: return []
        case 1: return [1]
        case 2: return [2]
        case 3: return [3]
        case 4: return [2, 2]
        case 5: return [3, 2]
        case 6: return [3, 3]
        default:
            var rows: [Int] = []
            var remaining = count
            while remaining > 0 {
                rows.append(min(4, remaining))
                remaining -= 4
            }
            return rows
        }
    }

    /// Rectangles des cases (origine en haut à gauche), ligne par ligne, de gauche à droite.
    /// Les lignes incomplètes gardent la taille de case des lignes pleines et sont centrées.
    static func frames(count: Int, in container: CGRect, margin: CGFloat = 48, spacing: CGFloat = 24) -> [CGRect] {
        let rows = rowCounts(for: count)
        guard let columns = rows.max() else { return [] }
        let area = container.insetBy(dx: margin, dy: margin)
        let tileWidth = (area.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let tileHeight = (area.height - spacing * CGFloat(rows.count - 1)) / CGFloat(rows.count)
        guard !area.isNull, tileWidth > 0, tileHeight > 0 else { return [] }

        var frames: [CGRect] = []
        for (rowIndex, rowCount) in rows.enumerated() {
            let rowWidth = tileWidth * CGFloat(rowCount) + spacing * CGFloat(rowCount - 1)
            let startX = area.minX + (area.width - rowWidth) / 2
            let y = area.minY + CGFloat(rowIndex) * (tileHeight + spacing)
            for column in 0..<rowCount {
                let x = startX + CGFloat(column) * (tileWidth + spacing)
                frames.append(CGRect(x: x, y: y, width: tileWidth, height: tileHeight))
            }
        }
        return frames
    }
}

extension GridLayout {
    /// Case située sous le point (même repère que `frames`), ou nil dans les marges et espacements.
    static func index(at point: CGPoint, in frames: [CGRect]) -> Int? {
        frames.firstIndex { $0.contains(point) }
    }
}
