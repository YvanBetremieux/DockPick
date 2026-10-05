import AppKit

struct PickerItem: Identifiable {
    let id: Int
    let title: String
    let isMinimized: Bool
    var thumbnail: NSImage?
}

@MainActor
final class PickerModel: ObservableObject {
    @Published var items: [PickerItem]
    @Published var selectedIndex: Int?
    let appIcon: NSImage?

    var onChoose: ((Int) -> Void)?
    var onCancel: (() -> Void)?

    init(items: [PickerItem], appIcon: NSImage?) {
        self.items = items
        self.appIcon = appIcon
    }

    func move(_ direction: MoveDirection) {
        selectedIndex = GridNavigation.move(from: selectedIndex, direction, rowCounts: GridLayout.rowCounts(for: items.count))
    }

    func choose(_ index: Int) {
        guard items.indices.contains(index) else { return }
        onChoose?(index)
    }

    func chooseSelected() {
        if let selectedIndex { choose(selectedIndex) }
    }

    func cancel() {
        onCancel?()
    }

    func setThumbnails(_ images: [Int: NSImage]) {
        for index in items.indices {
            if let image = images[items[index].id] { items[index].thumbnail = image }
        }
    }
}
