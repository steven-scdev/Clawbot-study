import Foundation

struct TaskOutput: Identifiable, Codable, Sendable {
    let id: String
    var taskId: String
    var type: OutputType
    var title: String
    var filePath: String?
    var url: String?
    var createdAt: Date
}

enum OutputType: String, Codable, Sendable {
    case file
    case website
    case document
    case image
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = OutputType(rawValue: rawValue) ?? .unknown
    }
}
