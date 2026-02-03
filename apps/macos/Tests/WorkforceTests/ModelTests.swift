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
        "unsupportedtype"
        """
        let outputType = try self.decoder.decode(OutputType.self, from: Data(json.utf8))
        #expect(outputType == .unknown)
    }

    @Test("decodes ISO 8601 string dates from gateway JSON")
    func decodesISO8601StringDate() throws {
        let json = """
        {"id":"o1","taskId":"t1","type":"file","title":"Report","createdAt":"2025-06-15T10:30:00Z"}
        """
        let decoder = JSONDecoder()
        let output = try decoder.decode(TaskOutput.self, from: Data(json.utf8))
        #expect(output.id == "o1")
        #expect(output.title == "Report")
        // Date should have been parsed from the ISO 8601 string
        #expect(output.createdAt.timeIntervalSince1970 > 0)
    }

    @Test("OutputType has distinct icons for all cases")
    func outputTypeIcons() {
        let icons = [OutputType.file, .website, .document, .image, .unknown].map(\.icon)
        #expect(Set(icons).count == 5)
    }
}

// MARK: - ISO 8601 Date Decoding

@Suite("ISO 8601 date decoding")
struct ISO8601DecodingTests {
    @Test("WorkforceTask decodes ISO 8601 string dates")
    func taskDecodesISO8601() throws {
        let json = """
        {
            "id":"t1","employeeId":"e1","description":"Test",
            "status":"running","stage":"execute","progress":0.5,
            "sessionKey":"wf-e1-abc","createdAt":"2025-06-15T10:30:00Z",
            "activities":[],"outputs":[]
        }
        """
        let decoder = JSONDecoder()
        let task = try decoder.decode(WorkforceTask.self, from: Data(json.utf8))
        #expect(task.id == "t1")
        #expect(task.createdAt.timeIntervalSince1970 > 0)
    }

    @Test("WorkforceTask uses defaults for missing optional fields")
    func taskDefaults() throws {
        let json = """
        {
            "id":"t2","employeeId":"e1","description":"Minimal",
            "status":"pending","stage":"clarify"
        }
        """
        let decoder = JSONDecoder()
        let task = try decoder.decode(WorkforceTask.self, from: Data(json.utf8))
        #expect(task.progress == 0.0)
        #expect(task.sessionKey == "")
        #expect(task.completedAt == nil)
        #expect(task.errorMessage == nil)
        #expect(task.activities.isEmpty)
        #expect(task.outputs.isEmpty)
    }

    @Test("TaskActivity decodes ISO 8601 string timestamps")
    func activityDecodesISO8601() throws {
        let json = """
        {"id":"a1","type":"thinking","message":"Working...","timestamp":"2025-06-15T10:30:00Z"}
        """
        let decoder = JSONDecoder()
        let activity = try decoder.decode(TaskActivity.self, from: Data(json.utf8))
        #expect(activity.id == "a1")
        #expect(activity.type == .thinking)
        #expect(activity.timestamp.timeIntervalSince1970 > 0)
    }
}

// MARK: - TaskFlowModels

@Suite("TaskFlowModels")
struct TaskFlowModelTests {
    @Test("ClarificationQuestion decodes with defaults")
    func clarificationDefaults() throws {
        let json = """
        {"id":"q1","text":"What framework?"}
        """
        let decoder = JSONDecoder()
        let question = try decoder.decode(ClarificationQuestion.self, from: Data(json.utf8))
        #expect(question.id == "q1")
        #expect(question.text == "What framework?")
        #expect(question.type == .text)
        #expect(question.required == false)
        #expect(question.options.isEmpty)
    }

    @Test("ClarificationQuestion decodes with all fields")
    func clarificationFullDecode() throws {
        let json = """
        {
            "id":"q2","text":"Pick a style","type":"single","required":true,
            "options":[{"id":"o1","label":"Modern","value":"modern"},{"label":"Classic"}]
        }
        """
        let decoder = JSONDecoder()
        let question = try decoder.decode(ClarificationQuestion.self, from: Data(json.utf8))
        #expect(question.type == .single)
        #expect(question.required == true)
        #expect(question.options.count == 2)
        #expect(question.options[0].value == "modern")
        // Second option should default value to label
        #expect(question.options[1].value == "Classic")
    }

    @Test("PlanPayload decodes structured plan")
    func planDecode() throws {
        let json = """
        {
            "summary":"Build a landing page",
            "steps":[
                {"id":"s1","description":"Create HTML structure"},
                {"description":"Add CSS styling"}
            ],
            "estimatedTime":"15 minutes"
        }
        """
        let decoder = JSONDecoder()
        let plan = try decoder.decode(PlanPayload.self, from: Data(json.utf8))
        #expect(plan.summary == "Build a landing page")
        #expect(plan.steps.count == 2)
        #expect(plan.steps[0].id == "s1")
        // Second step should auto-generate id
        #expect(!plan.steps[1].id.isEmpty)
        #expect(plan.estimatedTime == "15 minutes")
    }

    @Test("PlanPayload decodes without optional estimatedTime")
    func planWithoutTime() throws {
        let json = """
        {"summary":"Quick task","steps":[]}
        """
        let decoder = JSONDecoder()
        let plan = try decoder.decode(PlanPayload.self, from: Data(json.utf8))
        #expect(plan.estimatedTime == nil)
        #expect(plan.steps.isEmpty)
    }

    @Test("TaskCreateResponse decodes task wrapper")
    func taskCreateResponse() throws {
        let json = """
        {
            "task":{
                "id":"t1","employeeId":"e1","description":"Test",
                "status":"pending","stage":"clarify","progress":0,
                "sessionKey":"wf-e1-abc","createdAt":"2025-01-01T00:00:00Z",
                "activities":[],"outputs":[]
            }
        }
        """
        let decoder = JSONDecoder()
        let response = try decoder.decode(TaskCreateResponse.self, from: Data(json.utf8))
        #expect(response.task.id == "t1")
        #expect(response.task.status == .pending)
    }

    @Test("TaskListResponse decodes paginated list")
    func taskListResponse() throws {
        let json = """
        {"tasks":[],"total":0,"hasMore":false}
        """
        let decoder = JSONDecoder()
        let response = try decoder.decode(TaskListResponse.self, from: Data(json.utf8))
        #expect(response.tasks.isEmpty)
        #expect(response.total == 0)
        #expect(response.hasMore == false)
    }

    @Test("QuestionType unknown value decodes to .unknown")
    func unknownQuestionType() throws {
        let json = """
        "slider"
        """
        let decoder = JSONDecoder()
        let qt = try decoder.decode(QuestionType.self, from: Data(json.utf8))
        #expect(qt == .unknown)
    }
}

// MARK: - TaskFlowState

@Suite("TaskFlowState")
struct TaskFlowStateTests {
    @Test("idle states are equal")
    func idleEquality() {
        #expect(TaskFlowState.idle == TaskFlowState.idle)
    }

    @Test("executing states with same ID are equal")
    func executingEquality() {
        #expect(TaskFlowState.executing(taskId: "t1") == TaskFlowState.executing(taskId: "t1"))
    }

    @Test("executing states with different IDs are not equal")
    func executingInequality() {
        #expect(TaskFlowState.executing(taskId: "t1") != TaskFlowState.executing(taskId: "t2"))
    }

    @Test("different variants are not equal")
    func crossVariantInequality() {
        #expect(TaskFlowState.idle != TaskFlowState.executing(taskId: "t1"))
        #expect(TaskFlowState.executing(taskId: "t1") != TaskFlowState.reviewing(taskId: "t1"))
    }

    @Test("input states with same employee are equal")
    func inputEquality() {
        let emp = Employee.mockEmployees[0]
        #expect(TaskFlowState.input(employee: emp) == TaskFlowState.input(employee: emp))
    }
}
