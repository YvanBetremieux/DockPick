import SwiftUI

struct PickerView: View {
    @ObservedObject var model: PickerModel

    var body: some View {
        GeometryReader { geometry in
            let frames = GridLayout.frames(count: model.items.count, in: CGRect(origin: .zero, size: geometry.size))
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.25)
                    .contentShape(Rectangle())
                    .onTapGesture { model.cancel() }

                ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                    if index < frames.count {
                        let frame = frames[index]
                        TileView(item: item, appIcon: model.appIcon, number: index + 1, isSelected: model.selectedIndex == index)
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                            .onTapGesture { model.choose(index) }
                            .onHover { inside in if inside { model.selectedIndex = index } }
                    }
                }
            }
        }
    }
}

private struct TileView: View {
    let item: PickerItem
    let appIcon: NSImage?
    let number: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06))
                if let thumbnail = item.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(8)
                } else if let appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 96, height: 96)
                        .opacity(0.85)
                }
            }
            .overlay(alignment: .topLeading) {
                if number <= 9 {
                    Text("\(number)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                        .padding(10)
                }
            }
            .overlay(alignment: .topTrailing) {
                if item.isMinimized {
                    Text("Réduite")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .padding(10)
                }
            }

            HStack(spacing: 8) {
                if let appIcon {
                    Image(nsImage: appIcon).resizable().frame(width: 20, height: 20)
                }
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(isSelected ? 0.45 : 0.25)))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Color.accentColor : Color.white.opacity(0.12), lineWidth: isSelected ? 3 : 1)
        )
        .scaleEffect(isSelected ? 1.03 : 1)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .contentShape(Rectangle())
    }
}
