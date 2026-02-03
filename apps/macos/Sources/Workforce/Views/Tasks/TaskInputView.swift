import SwiftUI

// MARK: - Task Template

private struct TaskTemplate: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let description: String
    let icon: String
    let color: Color
}

// MARK: - TaskInputView

struct TaskInputView: View {
    let employee: Employee
    var taskService: TaskService
    var onTaskSubmitted: (WorkforceTask) -> Void
    var onCancel: () -> Void

    @State private var taskDescription = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var hoveredTemplateId: UUID?
    @State private var blobPhase: CGFloat = 0

    private let templates: [TaskTemplate] = [
        TaskTemplate(
            title: "Build a landing page",
            category: "Web Development",
            description: "Generate a responsive, high-converting HTML landing page structure.",
            icon: "globe",
            color: .indigo
        ),
        TaskTemplate(
            title: "Write a React component",
            category: "Frontend Engineering",
            description: "Create a functional React component with Tailwind CSS styling.",
            icon: "chevron.left.forwardslash.chevron.right",
            color: .blue
        ),
        TaskTemplate(
            title: "Analyze Dataset",
            category: "Data Science",
            description: "Upload a CSV and get key insights and visualization suggestions.",
            icon: "chart.bar.xaxis",
            color: .pink
        ),
    ]

    var body: some View {
        ZStack {
            // Animated gradient blobs
            self.blobBackground

            VStack(spacing: 0) {
                self.header

                // Scrollable content
                ScrollView {
                    VStack(spacing: 32) {
                        self.greeting
                            .padding(.top, 48)

                        self.templateGrid
                    }
                    .padding(.bottom, 120)
                }
            }

            // Floating input pill at bottom
            VStack {
                Spacer()
                self.inputPill
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                self.blobPhase = 1
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: self.onCancel) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.4))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("WORKFORCE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color(white: 0.45))

            Text("/")
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.6))

            Text("NEW TASK")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color(white: 0.35))

            Spacer()

            // Employee indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(self.employee.status.statusColor)
                    .frame(width: 6, height: 6)
                Text(self.employee.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.4))
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 0.5)
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(spacing: 6) {
            Text("Good morning, Alex")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color(white: 0.15))

            Text("Ready to start a new project?")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.45))
        }
    }

    // MARK: - Template Grid

    private var templateGrid: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(self.templates) { template in
                self.templateCard(template)
            }
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, 24)
    }

    private func templateCard(_ template: TaskTemplate) -> some View {
        let isHovered = self.hoveredTemplateId == template.id

        return Button {
            self.taskDescription = template.description
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Preview area with icon
                ZStack {
                    Color(white: 0.97).opacity(0.5)

                    // Faint wireframe preview lines
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(white: 0.82))
                            .frame(height: 2.5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(white: 0.82))
                            .frame(width: 70, height: 2.5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(white: 0.82))
                            .frame(height: 2.5)
                            .padding(.top, 4)
                    }
                    .opacity(0.4)
                    .padding(14)

                    // Colored icon badge
                    RoundedRectangle(cornerRadius: 11)
                        .fill(template.color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: template.icon)
                                .font(.system(size: 17))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: template.color.opacity(0.4), radius: 8, y: 3)
                        .offset(y: isHovered ? -3 : 0)
                }
                .frame(height: 90)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 0.5)

                // Text content
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(white: 0.15))

                    Text(template.category.uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Color(white: 0.5))

                    Text(template.description)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.45))
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.white.opacity(isHovered ? 0.55 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(isHovered ? 0.6 : 0.5), lineWidth: 1)
            )
            .shadow(
                color: Color(red: 0.12, green: 0.15, blue: 0.53).opacity(isHovered ? 0.12 : 0.06),
                radius: isHovered ? 12 : 6,
                y: isHovered ? 4 : 2
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.hoveredTemplateId = hovering ? template.id : nil
            }
        }
    }

    // MARK: - Floating Input Pill

    private var inputPill: some View {
        VStack(spacing: 6) {
            if let errorMessage = self.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 6) {
                TextField("Describe a new task...", text: self.$taskDescription)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.25))
                    .onSubmit {
                        Task { await self.submit() }
                    }

                Button {
                    Task { await self.submit() }
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
                .disabled(self.isSubmitDisabled)
                .opacity(self.isSubmitDisabled ? 0.5 : 1)
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
        .frame(maxWidth: 420)
        .padding(.bottom, 24)
    }

    private var isSubmitDisabled: Bool {
        self.taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.isSubmitting
    }

    // MARK: - Animated Blob Background

    private var blobBackground: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 350, height: 350)
                .blur(radius: 80)
                .offset(
                    x: -80 + self.blobPhase * 60,
                    y: -120 - self.blobPhase * 50
                )

            Circle()
                .fill(Color.purple.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(
                    x: 100 - self.blobPhase * 40,
                    y: -60 + self.blobPhase * 40
                )

            Circle()
                .fill(Color.pink.opacity(0.10))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(
                    x: -30 - self.blobPhase * 20,
                    y: 200 - self.blobPhase * 60
                )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func submit() async {
        self.isSubmitting = true
        self.errorMessage = nil
        do {
            let task = try await self.taskService.submitTask(
                employeeId: self.employee.id,
                description: self.taskDescription.trimmingCharacters(in: .whitespacesAndNewlines))
            self.onTaskSubmitted(task)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        self.isSubmitting = false
    }
}
