import SwiftUI

struct SidebarNavButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 10) {
                Image(systemName: self.icon)
                    .font(.system(size: 15, weight: self.isSelected ? .semibold : .regular))
                    .foregroundStyle(self.isSelected ? .primary : .secondary)
                    .frame(width: 22)

                Text(self.label)
                    .font(.system(size: 13, weight: self.isSelected ? .medium : .regular))
                    .foregroundStyle(self.isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(self.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        self.isSelected ? Color.white.opacity(0.2) : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            self.isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: self.isHovered)
        .animation(.easeInOut(duration: 0.15), value: self.isSelected)
    }

    private var backgroundColor: some ShapeStyle {
        if self.isSelected {
            return AnyShapeStyle(.white.opacity(0.2))
        } else if self.isHovered {
            return AnyShapeStyle(.white.opacity(0.1))
        } else {
            return AnyShapeStyle(.clear)
        }
    }
}
