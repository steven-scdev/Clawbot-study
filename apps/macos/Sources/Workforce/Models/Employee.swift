import Foundation
import SwiftUI

struct Employee: Identifiable, Codable, Sendable, Equatable {
    let id: String
    var name: String
    var title: String
    var emoji: String
    var description: String
    var status: EmployeeStatus
    var capabilities: [String]
    var avatarSystemName: String
    var currentTaskId: String?

    init(
        id: String,
        name: String,
        title: String,
        emoji: String,
        description: String,
        status: EmployeeStatus,
        capabilities: [String],
        avatarSystemName: String = "person.circle.fill",
        currentTaskId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.emoji = emoji
        self.description = description
        self.status = status
        self.capabilities = capabilities
        self.avatarSystemName = avatarSystemName
        self.currentTaskId = currentTaskId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.title = try container.decode(String.self, forKey: .title)
        self.emoji = try container.decode(String.self, forKey: .emoji)
        self.description = try container.decode(String.self, forKey: .description)
        self.status = try container.decode(EmployeeStatus.self, forKey: .status)
        self.capabilities = try container.decode([String].self, forKey: .capabilities)
        self.avatarSystemName = try container.decodeIfPresent(String.self, forKey: .avatarSystemName) ?? "person.circle.fill"
        self.currentTaskId = try container.decodeIfPresent(String.self, forKey: .currentTaskId)
    }
}

enum EmployeeStatus: String, Codable, Sendable, CaseIterable {
    case online
    case idle
    case busy
    case offline
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = EmployeeStatus(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - Computed Helpers

extension Employee {
    var displayCapabilities: [String] {
        Array(self.capabilities.prefix(3))
    }
}

extension EmployeeStatus {
    var statusColor: Color {
        switch self {
        case .online: .green
        case .idle: .gray
        case .busy: .yellow
        case .offline, .unknown: .gray.opacity(0.5)
        }
    }

    var label: String {
        switch self {
        case .online: "ONLINE"
        case .idle: "IDLE"
        case .busy: "BUSY"
        case .offline: "OFFLINE"
        case .unknown: "UNKNOWN"
        }
    }
}
