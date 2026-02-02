import Foundation
import Testing

@testable import Workforce

@Suite("Employee model")
struct EmployeeTests {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("round-trips through JSON")
    func roundTrip() throws {
        let original = Employee.mockEmployees[0]
        let data = try self.encoder.encode(original)
        let decoded = try self.decoder.decode(Employee.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.emoji == original.emoji)
        #expect(decoded.status == original.status)
        #expect(decoded.capabilities == original.capabilities)
    }

    @Test("unknown status decodes to .unknown")
    func unknownStatus() throws {
        let json = """
        {"id":"x","name":"X","title":"T","emoji":"🤖","description":"D","status":"newstate","capabilities":[]}
        """
        let employee = try self.decoder.decode(Employee.self, from: Data(json.utf8))
        #expect(employee.status == .unknown)
    }

    @Test("mock employees have correct count")
    func mockCount() {
        #expect(Employee.mockEmployees.count == 3)
    }
}

@Suite("WorkforceTask model")
struct WorkforceTaskTests {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("round-trips through JSON")
    func roundTrip() throws {
        let original = WorkforceTask.mockTasks[0]
        let data = try self.encoder.encode(original)
        let decoded = try self.decoder.decode(WorkforceTask.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.employeeId == original.employeeId)
        #expect(decoded.status == original.status)
        #expect(decoded.stage == original.stage)
        #expect(decoded.activities.count == original.activities.count)
    }

    @Test("unknown TaskStatus decodes to .unknown")
    func unknownTaskStatus() throws {
        let json = """
        "futuristic"
        """
        let status = try self.decoder.decode(TaskStatus.self, from: Data(json.utf8))
        #expect(status == .unknown)
    }

    @Test("unknown TaskStage decodes to .unknown")
    func unknownTaskStage() throws {
        let json = """
        "brainstorm"
        """
        let stage = try self.decoder.decode(TaskStage.self, from: Data(json.utf8))
        #expect(stage == .unknown)
    }

    @Test("unknown ActivityType decodes to .unknown")
    func unknownActivityType() throws {
        let json = """
        "streaming"
        """
        let actType = try self.decoder.decode(ActivityType.self, from: Data(json.utf8))
        #expect(actType == .unknown)
    }

    @Test("TaskStage has label and icon for all cases")
    func stageProperties() {
        for stage in [TaskStage.clarify, .plan, .execute, .review, .deliver, .unknown] {
            #expect(!stage.label.isEmpty)
            #expect(!stage.icon.isEmpty)
        }
    }

    @Test("mock tasks cover multiple statuses")
    func mockVariety() {
        let statuses = Set(WorkforceTask.mockTasks.map(\.status))
        #expect(statuses.contains(.running))
        #expect(statuses.contains(.completed))
        #expect(statuses.contains(.failed))
    }
}

@Suite("TaskOutput model")
struct TaskOutputTests {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("round-trips through JSON")
    func roundTrip() throws {
        let original = TaskOutput.mockOutputs[0]
        let data = try self.encoder.encode(original)
        let decoded = try self.decoder.decode(TaskOutput.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.taskId == original.taskId)
        #expect(decoded.type == original.type)
        #expect(decoded.title == original.title)
    }

    @Test("unknown OutputType decodes to .unknown")
    func unknownOutputType() throws {
        let json = """
        "spreadsheet"
        """
        let outputType = try self.decoder.decode(OutputType.self, from: Data(json.utf8))
        #expect(outputType == .unknown)
    }
}
