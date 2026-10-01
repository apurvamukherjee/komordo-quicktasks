import Foundation
import FoundationModels
import KomodoCore

/// Which model answers the Assistant (FEATURES §4.19): Apple's on-device model when it's available, otherwise
/// Claude with the user's own key.
enum AssistantBrain: Equatable {
    case onDevice
    case claude

    static func pick(_ settings: AppSettings) -> AssistantBrain? {
        if AppleIntelligence.status == .available { return .onDevice }
        return settings.hasClaudeKey ? .claude : nil
    }

    func plan(_ text: String, context: AssistantContext, settings: AppSettings) async throws(AssistantError)
        -> AssistantPlan
    {
        let instructions = AssistantPrompt.instructions(for: context, request: text)
        switch self {
        case .onDevice:
            guard #available(macOS 26, *) else { throw .noBrain }
            return try await OnDeviceAssistant.plan(text, instructions: instructions)
        case .claude:
            let key: String?
            do {
                key = try KeychainSecret.claudeKey.read()
            } catch {
                throw .noKey
            }
            guard let key, !key.isEmpty else { throw .noKey }
            return try await ClaudeAssistant.plan(
                text, instructions: instructions, key: key, model: settings.claudeModel)
        }
    }
}

/// Why the Assistant couldn't answer, worded for the popover.
enum AssistantError: Error, Equatable {
    case noBrain
    case noKey
    case refused
    case unreachable
    case rejected(String)
    case unreadable

    var message: String {
        switch self {
        case .noBrain: "Turn on Apple Intelligence, or add a Claude key in Settings ▸ AI."
        case .noKey: "Add your Claude key in Settings ▸ AI."
        case .refused: "Claude declined that one. Try wording it another way."
        case .unreachable: "Couldn't reach Claude. Check your connection."
        case .rejected(let reason): "Claude said: \(reason)"
        case .unreadable: "That didn't come back as a plan. Try again."
        }
    }
}

// MARK: On this Mac

@available(macOS 26, *)
private enum OnDeviceAssistant {
    @Generable struct Draft {
        @Guide(description: "One or two short, friendly sentences about what you propose.")
        var reply: String
        @Guide(description: "New tasks, one per thing to do.")
        var add: [DraftTask]
        @Guide(description: "Changes to tasks that already exist.")
        var edit: [DraftEdit]
    }

    @Generable struct DraftTask {
        var title: String
        var list: String?
        // A fixed set keeps the small model from inventing dates; DayPhrase reads each one.
        @Guide(
            description: "The day the user gave for this task, or none",
            .anyOf(["none", "today", "tomorrow", "mon", "tue", "wed", "thu", "fri", "sat", "sun", "next week"]))
        var day: String
        @Guide(description: "Like 07:00 or 7pm when the user gives a time for this task, otherwise none")
        var time: String
        var estimateMinutes: Int?
        var notes: String?
        var subtasks: [String]
    }

    @Generable struct DraftEdit {
        @Guide(description: "The existing task's title")
        var task: String
        var title: String?
        var list: String?
        @Guide(description: "backlog, week or today")
        var column: String?
        var day: String?
        var time: String?
        var estimateMinutes: Int?
        var notes: String?
        var addSubtasks: [String]
        var logMinutes: Int?
        var done: Bool?
    }

    static func plan(_ text: String, instructions: String) async throws(AssistantError) -> AssistantPlan {
        let draft: Draft
        do {
            let session = LanguageModelSession(instructions: instructions)
            draft = try await session.respond(to: text, generating: Draft.self).content
        } catch {
            throw .unreadable
        }
        return AssistantPlan(
            reply: draft.reply,
            add: draft.add.map {
                .init(
                    title: $0.title, list: $0.list, day: $0.day == "none" ? nil : $0.day,
                    time: $0.time == "none" ? nil : $0.time, estimateMinutes: $0.estimateMinutes,
                    notes: $0.notes, subtasks: $0.subtasks)
            },
            edit: draft.edit.map {
                .init(
                    task: $0.task, title: $0.title, list: $0.list, column: $0.column, day: $0.day, time: $0.time,
                    estimateMinutes: $0.estimateMinutes, notes: $0.notes, addSubtasks: $0.addSubtasks,
                    logMinutes: $0.logMinutes, done: $0.done)
            })
    }
}

// MARK: Claude

/// One Messages API call with the plan's schema as structured output. Low effort, since turning a sentence into
/// tasks is quick work, and server-side fallbacks so a declined request is retried on another model.
private enum ClaudeAssistant {
    static func plan(_ text: String, instructions: String, key: String, model: String) async throws(AssistantError)
        -> AssistantPlan
    {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { throw .unreachable }
        let body: JSONValue = [
            "model": .string(model),
            "max_tokens": 16_000,
            "fallbacks": "default",
            "system": .string(instructions),
            "output_config": [
                "effort": "low", "format": ["type": "json_schema", "schema": AssistantPlan.jsonSchema],
            ],
            "messages": [["role": "user", "content": .string(text)]],
        ]
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")

        let reply: JSONValue
        let status: Int?
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            status = (response as? HTTPURLResponse)?.statusCode
            reply = try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            throw .unreachable
        }
        guard status == 200 else { throw .rejected(reply["error"]?["message"]?.string ?? "error \(status ?? 0)") }
        // A decline arrives as a 200 with no plan in it.
        guard reply["stop_reason"]?.string != "refusal" else { throw .refused }
        guard
            let json = reply["content"]?.array?.first(where: { $0["type"]?.string == "text" })?["text"]?.string,
            let plan = try? JSONDecoder().decode(AssistantPlan.self, from: Data(json.utf8))
        else { throw .unreadable }
        return plan
    }
}
