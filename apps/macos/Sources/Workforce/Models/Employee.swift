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
    var avatarSystemName: String = "person.circle.fill"
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
