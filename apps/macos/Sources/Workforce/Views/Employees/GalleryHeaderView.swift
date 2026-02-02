import SwiftUI

struct GalleryHeaderView: View {
    let employeeCount: Int
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 12) {
            // Title + count
            Text("Select Employee")
                .font(.system(size: 17, weight: .semibold))

            // Count badge
            Text("\(self.employeeCount) Available")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.15))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )

            Spacer()

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField("Search skills...", text: self.$searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !self.searchText.isEmpty {
                    Button {
                        self.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 200)
            .background(
                Capsule()
                    .fill(.white.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )

            // Filter button
            Button {
                // Filter action placeholder
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}
