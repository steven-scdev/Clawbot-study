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
    var outputs: [TaskOutput]

    private enum CodingKeys: String, CodingKey {
        case id, employeeId, description, status, stage, progress, sessionKey
        case createdAt, completedAt, errorMessage, activities, outputs
    }

    static func == (lhs: WorkforceTask, rhs: WorkforceTask) -> Bool {
        lhs.id == rhs.id
    }

    init(
        id: String,
        employeeId: String,
        description: String,
        status: TaskStatus,
        stage: TaskStage,
        progress: Double,
        sessionKey: String,
        createdAt: Date,
        completedAt: Date? = nil,
        errorMessage: String? = nil,
        activities: [TaskActivity] = [],
        outputs: [TaskOutput] = []
    ) {
        self.id = id
        self.employeeId = employeeId
        self.description = description
        self.status = status
        self.stage = stage
        self.progress = progress
        self.sessionKey = sessionKey
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.errorMessage = errorMessage
        self.activities = activities
        self.outputs = outputs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.employeeId = try container.decode(String.self, forKey: .employeeId)
        self.description = try container.decode(String.self, forKey: .description)
        self.status = try container.decode(TaskStatus.self, forKey: .status)
        self.stage = try container.decode(TaskStage.self, forKey: .stage)
        self.progress = try container.decodeIfPresent(Double.self, forKey: .progress) ?? 0.0
        self.sessionKey = try container.decodeIfPresent(String.self, forKey: .sessionKey) ?? ""
        self.createdAt = Self.decodeDate(from: container, forKey: .createdAt) ?? Date()
        self.completedAt = Self.decodeDate(from: container, forKey: .completedAt)
        self.errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        self.activities = try container.decodeIfPresent([TaskActivity].self, forKey: .activities) ?? []
        self.outputs = try container.decodeIfPresent([TaskOutput].self, forKey: .outputs) ?? []
    }

    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        if let str = try? container.decode(String.self, forKey: key) {
            return ISO8601DateFormatter().date(from: str)
        }
        return nil
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
    case prepare
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
        case .prepare: "Preparing"
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
        case .prepare: "sparkle.magnifyingglass"
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

    init(id: String, type: ActivityType, message: String, timestamp: Date, detail: String? = nil) {
        self.id = id
        self.type = type
        self.message = message
        self.timestamp = timestamp
        self.detail = detail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(ActivityType.self, forKey: .type)
        self.message = try container.decode(String.self, forKey: .message)
        if let date = try? container.decode(Date.self, forKey: .timestamp) {
            self.timestamp = date
        } else if let str = try? container.decode(String.self, forKey: .timestamp) {
            self.timestamp = ISO8601DateFormatter().date(from: str) ?? Date()
        } else {
            self.timestamp = Date()
        }
        self.detail = try container.decodeIfPresent(String.self, forKey: .detail)
    }
}

enum ActivityType: String, Codable, Sendable {
    case thinking
    case toolCall
    case toolResult
    case text
    case userMessage
    case error
    case completion
    case planning
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
        case .userMessage: "person.fill"
        case .error: "exclamationmark.triangle"
        case .completion: "checkmark.circle.fill"
        case .planning: "sparkle.magnifyingglass"
        case .unknown: "circle"
        }
    }
}
