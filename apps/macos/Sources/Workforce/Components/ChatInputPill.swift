import SwiftUI

struct ChatInputPill: View {
    @Binding var text: String
    var placeholder: String = "Describe a new task..."
    var isSubmitting: Bool = false
    var errorMessage: String?
    var onSubmit: () async -> Void

    private var isDisabled: Bool {
        self.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.isSubmitting
    }

    var body: some View {
        VStack(spacing: 6) {
            if let errorMessage = self.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 6) {
                TextField(self.placeholder, text: self.$text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.25))
                    .onSubmit {
                        Task { await self.onSubmit() }
                    }

                Button {
                    Task { await self.onSubmit() }
                } label: {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(self.isDisabled)
                .opacity(self.isDisabled ? 0.5 : 1)
            }
            .padding(.leading, 20)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.7))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
        }
        .frame(maxWidth: 500)
        .padding(.bottom, 24)
    }
}
