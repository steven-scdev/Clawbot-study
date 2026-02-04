import Foundation

// MARK: - Task Create Response

struct TaskCreateResponse: Codable, Sendable {
    let task: WorkforceTask

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.task = try container.decode(WorkforceTask.self, forKey: .task)
    }
}

// MARK: - Clarification

struct ClarificationPayload: Codable, Sendable, Equatable {
    let questions: [ClarificationQuestion]

    init(questions: [ClarificationQuestion]) {
        self.questions = questions
    }
}

struct ClarificationQuestion: Identifiable, Codable, Sendable, Equatable {
    let id: String
    var text: String
    var type: QuestionType
    var required: Bool
    var options: [QuestionOption]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.text = try container.decode(String.self, forKey: .text)
        self.type = try container.decodeIfPresent(QuestionType.self, forKey: .type) ?? .text
        self.required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        self.options = try container.decodeIfPresent([QuestionOption].self, forKey: .options) ?? []
    }
}

enum QuestionType: String, Codable, Sendable {
    case single
    case multiple
    case text
    case file
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = QuestionType(rawValue: rawValue) ?? .unknown
    }
}

struct QuestionOption: Identifiable, Codable, Sendable, Equatable {
    let id: String
    var label: String
    var value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.label = try container.decode(String.self, forKey: .label)
        self.value = try container.decodeIfPresent(String.self, forKey: .value) ?? self.label
    }
}

struct ClarificationAnswer: Codable, Sendable {
    let questionId: String
    let value: String
}

// MARK: - Plan

struct PlanPayload: Codable, Sendable, Equatable {
    let summary: String
    let steps: [PlanStep]
    let estimatedTime: String?

    init(summary: String, steps: [PlanStep], estimatedTime: String? = nil) {
        self.summary = summary
        self.steps = steps
        self.estimatedTime = estimatedTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.steps = try container.decodeIfPresent([PlanStep].self, forKey: .steps) ?? []
        self.estimatedTime = try container.decodeIfPresent(String.self, forKey: .estimatedTime)
    }
}

struct PlanStep: Identifiable, Codable, Sendable, Equatable {
    let id: String
    var description: String
    var estimatedTime: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.description = try container.decode(String.self, forKey: .description)
        self.estimatedTime = try container.decodeIfPresent(String.self, forKey: .estimatedTime)
    }
}

// MARK: - Task List Response

struct TaskListResponse: Codable, Sendable {
    let tasks: [WorkforceTask]
    let total: Int
    let hasMore: Bool
}

// MARK: - Task Flow State

enum TaskFlowState: Equatable {
    case idle
    case input(employee: Employee)
    case chatting(employee: Employee, taskId: String)
    case clarifying(task: WorkforceTask, questions: ClarificationPayload)
    case planning(task: WorkforceTask, plan: PlanPayload)
    case executing(taskId: String)
    case reviewing(taskId: String)

    static func == (lhs: TaskFlowState, rhs: TaskFlowState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case let (.input(a), .input(b)):
            return a.id == b.id
        case let (.chatting(a, aId), .chatting(b, bId)):
            return a.id == b.id && aId == bId
        case let (.clarifying(a, _), .clarifying(b, _)):
            return a.id == b.id
        case let (.planning(a, _), .planning(b, _)):
            return a.id == b.id
        case let (.executing(a), .executing(b)):
            return a == b
        case let (.reviewing(a), .reviewing(b)):
            return a == b
        default:
            return false
        }
    }
}
