import SwiftUI

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id: String
    let role: Role
    let content: String
    let timestamp: Date

    enum Role {
        case user
        case assistant
        case system
        case error
    }
}

// MARK: - ChatBubbleView

struct ChatBubbleView: View {
    let message: ChatMessage
    let employeeName: String

    var body: some View {
        switch self.message.role {
        case .user:
            self.userBubble
        case .assistant:
            self.assistantBubble
        case .system:
            self.systemBubble
        case .error:
            self.errorBubble
        }
    }

    // MARK: - Assistant Bubble (left-aligned, glass-emma)

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            // Sparkles avatar
            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )

            // Glass-emma bubble
            VStack(alignment: .leading, spacing: 0) {
                MarkdownText(content: self.message.content, fontSize: 15)
                    .foregroundStyle(Color(white: 0.15))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.25))
            .background(.ultraThinMaterial)
            .clipShape(BubbleShape(isUser: false))
            .overlay(
                BubbleShape(isUser: false)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 10, y: 2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 60)
    }

    // MARK: - User Bubble (right-aligned, glass-user)

    private var userBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer(minLength: 0)

            // Glass-user bubble
            VStack(alignment: .leading, spacing: 0) {
                MarkdownText(content: self.message.content, fontSize: 15)
                    .foregroundStyle(Color(white: 0.15))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.7))
            .background(.ultraThinMaterial)
            .clipShape(BubbleShape(isUser: true))
            .overlay(
                BubbleShape(isUser: true)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 12, y: 2)

            // Blue user avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                )
                .shadow(color: .blue.opacity(0.2), radius: 4, y: 2)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 60)
    }

    // MARK: - Typing Indicator Bubble

    static func typingBubble(employeeName: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )

            HStack(spacing: 0) {
                TypingIndicatorView()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.25))
            .background(.ultraThinMaterial)
            .clipShape(BubbleShape(isUser: false))
            .overlay(
                BubbleShape(isUser: false)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
        .padding(.trailing, 60)
    }

    // MARK: - System Message

    private var systemBubble: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
            Text(self.message.content)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(white: 0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Error Message

    private var errorBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.red.opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                )

            VStack(alignment: .leading, spacing: 0) {
                MarkdownText(content: self.message.content, fontSize: 15)
                    .foregroundStyle(Color.red.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.08))
            .background(.ultraThinMaterial)
            .clipShape(BubbleShape(isUser: false))
            .overlay(
                BubbleShape(isUser: false)
                    .stroke(Color.red.opacity(0.15), lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
        .padding(.trailing, 60)
    }
}

// MARK: - Bubble Shape

private struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let smallRadius: CGFloat = 4

        var path = Path()

        if self.isUser {
            // User bubble: top-right corner is sharp
            path.addRoundedRect(
                in: rect,
                cornerRadii: RectangleCornerRadii(
                    topLeading: radius,
                    bottomLeading: radius,
                    bottomTrailing: radius,
                    topTrailing: smallRadius
                )
            )
        } else {
            // Assistant bubble: top-left corner is sharp
            path.addRoundedRect(
                in: rect,
                cornerRadii: RectangleCornerRadii(
                    topLeading: smallRadius,
                    bottomLeading: radius,
                    bottomTrailing: radius,
                    topTrailing: radius
                )
            )
        }

        return path
    }
}

// MARK: - Markdown Text Renderer

/// Renders markdown text with proper formatting (bold, italic, lists, etc.)
private struct MarkdownText: View {
    let content: String
    let fontSize: CGFloat

    var body: some View {
        Text(self.attributedContent)
            .lineSpacing(6)
    }

    private var attributedContent: AttributedString {
        do {
            // Parse markdown and create attributed string
            var attributedString = try AttributedString(
                markdown: self.content,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )

            // Apply base font size
            attributedString.font = .system(size: self.fontSize)

            return attributedString
        } catch {
            // Fallback to plain text if markdown parsing fails
            var fallback = AttributedString(self.content)
            fallback.font = .system(size: self.fontSize)
            return fallback
        }
    }
}
