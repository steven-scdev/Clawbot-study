import SwiftUI

struct ClarificationView: View {
    let task: WorkforceTask
    let questions: ClarificationPayload
    let employee: Employee?
    var taskService: TaskService
    var onComplete: (WorkforceTask) -> Void
    var onCancel: () -> Void

    @State private var answers: [String: String] = [:]
    @State private var multiAnswers: [String: Set<String>] = [:]
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.header
            Divider()
            self.questionList
            Divider()
            self.controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            if let employee {
                Text(employee.emoji)
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text(employee.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Needs a few details before starting")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
        }
        .padding(20)
    }

    // MARK: - Questions

    private var questionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(self.task.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                ForEach(self.questions.questions) { question in
                    self.questionView(for: question)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func questionView(for question: ClarificationQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(question.text)
                    .font(.headline)
                if question.required {
                    Text("*")
                        .foregroundStyle(.red)
                }
            }

            switch question.type {
            case .single:
                self.singleSelect(for: question)
            case .multiple:
                self.multipleSelect(for: question)
            case .text, .file, .unknown:
                self.textInput(for: question)
            }
        }
    }

    private func singleSelect(for question: ClarificationQuestion) -> some View {
        Picker("", selection: self.binding(for: question.id)) {
            Text("Select...").tag("")
            ForEach(question.options) { option in
                Text(option.label).tag(option.value)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
    }

    private func multipleSelect(for question: ClarificationQuestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(question.options) { option in
                Toggle(isOn: self.multiBinding(questionId: question.id, value: option.value)) {
                    Text(option.label)
                        .font(.body)
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    private func textInput(for question: ClarificationQuestion) -> some View {
        TextEditor(text: self.binding(for: question.id))
            .font(.body)
            .frame(minHeight: 60, maxHeight: 120)
            .padding(4)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - Controls

    private var controls: some View {
        HStack {
            Button("Cancel") {
                self.onCancel()
            }
            .buttonStyle(.bordered)

            Spacer()

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Continue") {
                Task { await self.submit() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!self.isValid || self.isSubmitting)
        }
        .padding(20)
    }

    // MARK: - Bindings

    private func binding(for questionId: String) -> Binding<String> {
        Binding(
            get: { self.answers[questionId] ?? "" },
            set: { self.answers[questionId] = $0 }
        )
    }

    private func multiBinding(questionId: String, value: String) -> Binding<Bool> {
        Binding(
            get: { self.multiAnswers[questionId, default: []].contains(value) },
            set: { isOn in
                if isOn {
                    self.multiAnswers[questionId, default: []].insert(value)
                } else {
                    self.multiAnswers[questionId, default: []].remove(value)
                }
            }
        )
    }

    // MARK: - Validation

    private var isValid: Bool {
        for question in self.questions.questions where question.required {
            switch question.type {
            case .multiple:
                if self.multiAnswers[question.id, default: []].isEmpty { return false }
            default:
                let answer = self.answers[question.id] ?? ""
                if answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
            }
        }
        return true
    }

    // MARK: - Submit

    private func submit() async {
        self.isSubmitting = true
        self.errorMessage = nil

        var collected: [ClarificationAnswer] = []
        for question in self.questions.questions {
            let value: String
            switch question.type {
            case .multiple:
                value = self.multiAnswers[question.id, default: []].sorted().joined(separator: ",")
            default:
                value = self.answers[question.id] ?? ""
            }
            collected.append(ClarificationAnswer(questionId: question.id, value: value))
        }

        do {
            let updated = try await self.taskService.submitClarification(
                taskId: self.task.id, answers: collected)
            self.onComplete(updated)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        self.isSubmitting = false
    }
}
