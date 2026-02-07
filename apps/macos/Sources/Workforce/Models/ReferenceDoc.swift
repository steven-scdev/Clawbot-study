import Foundation

struct ReferenceDoc: Identifiable, Codable, Sendable {
    let id: String
    var originalName: String
    var addedAt: String
    var addedVia: String        // "chat" | "api" | "manual"
    var type: String            // "template" | "example" | "style-guide" | "reference"
    var digest: String
    var tags: [String]
    var fileSize: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.originalName = try container.decode(String.self, forKey: .originalName)
        self.addedAt = try container.decode(String.self, forKey: .addedAt)
        self.addedVia = try container.decodeIfPresent(String.self, forKey: .addedVia) ?? "chat"
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "reference"
        self.digest = try container.decodeIfPresent(String.self, forKey: .digest) ?? ""
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.fileSize = try container.decodeIfPresent(Int.self, forKey: .fileSize) ?? 0
    }
}

/// Response wrapper for workforce.references.list gateway method.
struct ReferenceListResponse: Codable, Sendable {
    let references: [ReferenceDoc]
}
