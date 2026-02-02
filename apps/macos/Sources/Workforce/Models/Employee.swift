import Foundation

struct Employee: Identifiable, Codable, Sendable, Equatable {
    let id: String
    var name: String
    var title: String
    var emoji: String
    var description: String
    var status: EmployeeStatus
    var capabilities: [String]
}

enum EmployeeStatus: String, Codable, Sendable, CaseIterable {
    case online
    case busy
    case offline
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = EmployeeStatus(rawValue: rawValue) ?? .unknown
    }
}
