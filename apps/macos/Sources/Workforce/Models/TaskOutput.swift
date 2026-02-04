import Foundation

struct TaskOutput: Identifiable, Codable, Sendable {
    let id: String
    var taskId: String
    var type: OutputType
    var title: String
    var filePath: String?
    var url: String?
    var createdAt: Date

    init(
        id: String,
        taskId: String,
        type: OutputType,
        title: String,
        filePath: String? = nil,
        url: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.taskId = taskId
        self.type = type
        self.title = title
        self.filePath = filePath
        self.url = url
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.taskId = try container.decodeIfPresent(String.self, forKey: .taskId) ?? ""
        self.type = try container.decode(OutputType.self, forKey: .type)
        self.title = try container.decode(String.self, forKey: .title)
        self.filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        if let date = try? container.decode(Date.self, forKey: .createdAt) {
            self.createdAt = date
        } else if let str = try? container.decode(String.self, forKey: .createdAt) {
            self.createdAt = ISO8601DateFormatter().date(from: str) ?? Date()
        } else {
            self.createdAt = Date()
        }
    }
}

enum OutputType: String, Codable, Sendable {
    case file
    case website
    case document
    case image
    case presentation
    case spreadsheet
    case video
    case audio
    case code
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = OutputType(rawValue: rawValue) ?? .unknown
    }
}
