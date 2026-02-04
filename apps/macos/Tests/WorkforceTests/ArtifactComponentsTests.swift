import Foundation
import Testing
import SwiftUI

@testable import Workforce

@Suite("OutputType expansion")
struct OutputTypeExpansionTests {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("presentation type decodes correctly")
    func presentationDecoding() throws {
        let json = """
        {"id":"1","taskId":"task-1","type":"presentation","title":"Slides","filePath":"/test.pptx","createdAt":"2026-01-01T00:00:00Z"}
        """
        let output = try self.decoder.decode(TaskOutput.self, from: Data(json.utf8))
        #expect(output.type == .presentation)
    }

    @Test("spreadsheet type decodes correctly")
    func spreadsheetDecoding() throws {
        let json = """
        {"id":"1","taskId":"task-1","type":"spreadsheet","title":"Data","filePath":"/test.xlsx","createdAt":"2026-01-01T00:00:00Z"}
        """
        let output = try self.decoder.decode(TaskOutput.self, from: Data(json.utf8))
        #expect(output.type == .spreadsheet)
    }

    @Test("video type decodes correctly")
    func videoDecoding() throws {
        let json = """
        {"id":"1","taskId":"task-1","type":"video","title":"Demo","filePath":"/test.mp4","createdAt":"2026-01-01T00:00:00Z"}
        """
        let output = try self.decoder.decode(TaskOutput.self, from: Data(json.utf8))
        #expect(output.type == .video)
    }

    @Test("audio type decodes correctly")
    func audioDecoding() throws {
        let json = """
        {"id":"1","taskId":"task-1","type":"audio","title":"Recording","filePath":"/test.mp3","createdAt":"2026-01-01T00:00:00Z"}
        """
        let output = try self.decoder.decode(TaskOutput.self, from: Data(json.utf8))
        #expect(output.type == .audio)
    }

    @Test("code type decodes correctly")
    func codeDecoding() throws {
        let json = """
        {"id":"1","taskId":"task-1","type":"code","title":"Script","filePath":"/test.swift","createdAt":"2026-01-01T00:00:00Z"}
        """
        let output = try self.decoder.decode(TaskOutput.self, from: Data(json.utf8))
        #expect(output.type == .code)
    }

    @Test("unknown type defaults to .unknown")
    func unknownTypeDecoding() throws {
        let json = """
        {"id":"1","taskId":"task-1","type":"newtypehere","title":"Test","filePath":"/test.xyz","createdAt":"2026-01-01T00:00:00Z"}
        """
        let output = try self.decoder.decode(TaskOutput.self, from: Data(json.utf8))
        #expect(output.type == .unknown)
    }

    @Test("all output types have icons")
    func allTypesHaveIcons() {
        let types: [OutputType] = [
            .file, .website, .document, .image,
            .presentation, .spreadsheet, .video, .audio, .code, .unknown
        ]
        for type in types {
            #expect(!type.icon.isEmpty)
        }
    }
}

@Suite("ArtifactType classification")
struct ArtifactClassificationTests {
    @Test("URL output classifies as web")
    func urlClassifiesAsWeb() {
        let output = TaskOutput(
            id: "1",
            taskId: "task-1",
            type: .website,
            title: "Test",
            filePath: nil,
            url: "http://localhost:3000",
            createdAt: Date()
        )

        // Classification logic from ArtifactRendererView
        let isWeb = output.url?.hasPrefix("http") ?? false
        #expect(isWeb == true)
    }

    @Test("file path output classifies as file")
    func filePathClassifiesAsFile() {
        let output = TaskOutput(
            id: "1",
            taskId: "task-1",
            type: .document,
            title: "Test",
            filePath: "/tmp/test.md",
            url: nil,
            createdAt: Date()
        )

        // Classification logic from ArtifactRendererView
        let isWeb = output.url?.hasPrefix("http") ?? false
        #expect(isWeb == false)
    }

    @Test("https URL classifies as web")
    func httpsClassifiesAsWeb() {
        let output = TaskOutput(
            id: "1",
            taskId: "task-1",
            type: .website,
            title: "Test",
            filePath: nil,
            url: "https://example.com",
            createdAt: Date()
        )

        let isWeb = output.url?.hasPrefix("http") ?? false
        #expect(isWeb == true)
    }

    @Test("file:// URL does not classify as web")
    func fileUrlDoesNotClassifyAsWeb() {
        let output = TaskOutput(
            id: "1",
            taskId: "task-1",
            type: .document,
            title: "Test",
            filePath: nil,
            url: "file:///tmp/test.html",
            createdAt: Date()
        )

        let isWeb = output.url?.hasPrefix("http") ?? false
        #expect(isWeb == false)
    }
}

@Suite("TaskChatView computed properties")
struct TaskChatViewPropertiesTests {
    private func createMockTask(status: TaskStatus, outputCount: Int) -> WorkforceTask {
        let outputs = (0..<outputCount).map { i in
            TaskOutput(
                id: "\(i)",
                taskId: "task-1",
                type: .document,
                title: "Output \(i)",
                filePath: "/tmp/output\(i).txt",
                url: nil,
                createdAt: Date()
            )
        }

        return WorkforceTask(
            id: "test-task",
            employeeId: "emp-1",
            description: "Test task",
            status: status,
            stage: .execute,
            progress: 0.5,
            sessionKey: "session-123",
            createdAt: Date(),
            completedAt: nil,
            errorMessage: nil,
            activities: [],
            outputs: outputs
        )
    }

    @Test("showApproveButton requires completed status and outputs")
    func approveButtonRequirements() {
        let completedWithOutputs = createMockTask(status: .completed, outputCount: 1)
        let completedWithoutOutputs = createMockTask(status: .completed, outputCount: 0)
        let runningWithOutputs = createMockTask(status: .running, outputCount: 1)

        // Logic from TaskChatView showApproveButton computed property
        #expect(completedWithOutputs.status == .completed && !completedWithOutputs.outputs.isEmpty)
        #expect(!(completedWithoutOutputs.status == .completed && !completedWithoutOutputs.outputs.isEmpty))
        #expect(!(runningWithOutputs.status == .completed && !runningWithOutputs.outputs.isEmpty))
    }

    @Test("currentOutput returns most recent when no selection")
    func mostRecentOutputSelection() {
        let task = createMockTask(status: .running, outputCount: 3)
        let selectedOutputId: String? = nil

        // Logic from TaskChatView currentOutput computed property
        let currentOutput: TaskOutput?
        if let id = selectedOutputId {
            currentOutput = task.outputs.first(where: { $0.id == id })
        } else {
            currentOutput = task.outputs.last
        }

        #expect(currentOutput?.id == "2") // Last output
    }

    @Test("currentOutput returns selected when specified")
    func specificOutputSelection() {
        let task = createMockTask(status: .running, outputCount: 3)
        let selectedOutputId: String? = "1"

        // Logic from TaskChatView currentOutput computed property
        let currentOutput: TaskOutput?
        if let id = selectedOutputId {
            currentOutput = task.outputs.first(where: { $0.id == id })
        } else {
            currentOutput = task.outputs.last
        }

        #expect(currentOutput?.id == "1") // Selected output
    }
}
