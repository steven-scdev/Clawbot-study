import SwiftUI

struct ContentPlaceholderView: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: self.icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(self.title)
                .font(.title)
                .fontWeight(.semibold)
            Text(self.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
