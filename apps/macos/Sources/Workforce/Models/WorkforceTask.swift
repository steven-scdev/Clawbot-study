import Foundation

struct WorkforceTask: Identifiable, Codable, Sendable, Equatable {
    let id: String
    var employeeId: String
    var description: String
    var status: TaskStatus
    var stage: TaskStage
    var progress: Double
    var sessionKey: String
    var createdAt: Date
    var completedAt: Date?
    var errorMessage: String?
    var activities: [TaskActivity]

    static func == (lhs: WorkforceTask, rhs: WorkforceTask) -> Bool {
        lhs.id == rhs.id
    }
}

enum TaskStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = TaskStatus(rawValue: rawValue) ?? .unknown
    }
}

enum TaskStage: String, Codable, Sendable {
    case clarify
    case plan
    case execute
    case review
    case deliver
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = TaskStage(rawValue: rawValue) ?? .unknown
    }

    var label: String {
        switch self {
        case .clarify: "Clarify"
        case .plan: "Plan"
        case .execute: "Execute"
        case .review: "Review"
        case .deliver: "Deliver"
        case .unknown: "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .clarify: "questionmark.circle"
        case .plan: "map"
        case .execute: "hammer"
        case .review: "eye"
        case .deliver: "checkmark.circle"
        case .unknown: "circle.dashed"
        }
    }
}

struct TaskActivity: Identifiable, Codable, Sendable {
    let id: String
    var type: ActivityType
    var message: String
    var timestamp: Date
    var detail: String?
}

enum ActivityType: String, Codable, Sendable {
    case thinking
    case toolCall
    case toolResult
    case text
    case error
    case completion
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = ActivityType(rawValue: rawValue) ?? .unknown
    }

    var icon: String {
        switch self {
        case .thinking: "brain"
        case .toolCall: "wrench.and.screwdriver"
        case .toolResult: "checkmark.rectangle"
        case .text: "text.bubble"
        case .error: "exclamationmark.triangle"
        case .completion: "checkmark.circle.fill"
        case .unknown: "circle"
        }
    }
}
