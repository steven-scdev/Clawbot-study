import SwiftUI

struct ChatInputPill: View {
    @Binding var text: String
    @Binding var attachments: [URL]
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

            // Attachment chips row
            if !self.attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(self.attachments, id: \.absoluteString) { url in
                            HStack(spacing: 4) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.blue)
                                Text(url.lastPathComponent)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color(white: 0.3))
                                    .lineLimit(1)
                                Button {
                                    self.attachments.removeAll { $0 == url }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(white: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 6) {
                // Paperclip button for file attachments
                Button {
                    self.openFilePicker()
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(white: 0.45))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

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
            .padding(.leading, 12)
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

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            if response == .OK {
                self.attachments.append(contentsOf: panel.urls)
            }
        }
    }
}
