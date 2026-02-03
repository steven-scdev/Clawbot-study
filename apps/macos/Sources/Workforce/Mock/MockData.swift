import Foundation

extension Employee {
    static let mockEmployees: [Employee] = [
        Employee(
            id: "emma-web",
            name: "Emma",
            title: "Creative Strategist",
            emoji: "🌐",
            description: "Creates professional websites and landing pages",
            status: .online,
            capabilities: ["Trend Analysis", "Copywriting", "Web Design", "React"],
            avatarSystemName: "person.circle.fill"),
        Employee(
            id: "david-decks",
            name: "David",
            title: "Data Analyst",
            emoji: "📊",
            description: "Creates professional presentation decks and data visualizations",
            status: .idle,
            capabilities: ["Data Visualization", "Complex Modeling", "Presentations"],
            avatarSystemName: "person.circle.fill"),
        Employee(
            id: "sarah-research",
            name: "Sarah",
            title: "Senior Engineer",
            emoji: "🔍",
            description: "Deep research, system design, and full stack development",
            status: .busy,
            capabilities: ["Full Stack Dev", "System Design", "Research"],
            avatarSystemName: "person.circle.fill"),
    ]
}

extension WorkforceTask {
    static let mockTasks: [WorkforceTask] = [
        WorkforceTask(
            id: "task-1",
            employeeId: "emma-web",
            description: "Build a landing page for our new product launch",
            status: .running,
            stage: .execute,
            progress: 0.45,
            sessionKey: "workforce-emma-web-abc123",
            createdAt: Date().addingTimeInterval(-3600),
            activities: [
                TaskActivity(
                    id: "a1", type: .thinking,
                    message: "Analyzing requirements for landing page",
                    timestamp: Date().addingTimeInterval(-3500)),
                TaskActivity(
                    id: "a2", type: .toolCall,
                    message: "Creating index.html",
                    timestamp: Date().addingTimeInterval(-3400)),
                TaskActivity(
                    id: "a3", type: .toolCall,
                    message: "Writing styles.css",
                    timestamp: Date().addingTimeInterval(-3200)),
            ],
            outputs: []),
        WorkforceTask(
            id: "task-2",
            employeeId: "sarah-research",
            description: "Research competitor pricing strategies in the SaaS market",
            status: .completed,
            stage: .deliver,
            progress: 1.0,
            sessionKey: "workforce-sarah-research-def456",
            createdAt: Date().addingTimeInterval(-7200),
            completedAt: Date().addingTimeInterval(-3600),
            activities: [],
            outputs: []),
        WorkforceTask(
            id: "task-3",
            employeeId: "david-decks",
            description: "Create Q4 board presentation with revenue charts",
            status: .failed,
            stage: .execute,
            progress: 0.3,
            sessionKey: "workforce-david-decks-ghi789",
            createdAt: Date().addingTimeInterval(-5400),
            errorMessage: "Failed to generate chart: missing data source",
            activities: [
                TaskActivity(
                    id: "a4", type: .toolCall,
                    message: "Reading quarterly data",
                    timestamp: Date().addingTimeInterval(-5300)),
                TaskActivity(
                    id: "a5", type: .error,
                    message: "Data source not found: revenue_q4.csv",
                    timestamp: Date().addingTimeInterval(-5200)),
            ],
            outputs: []),
    ]
}

extension TaskOutput {
    static let mockOutputs: [TaskOutput] = [
        TaskOutput(
            id: "out-1",
            taskId: "task-2",
            type: .document,
            title: "Competitor Pricing Analysis",
            filePath: "/tmp/workforce/competitor-analysis.md",
            createdAt: Date().addingTimeInterval(-3600)),
        TaskOutput(
            id: "out-2",
            taskId: "task-1",
            type: .website,
            title: "Product Landing Page",
            url: "http://localhost:3000",
            createdAt: Date().addingTimeInterval(-1800)),
    ]
}
