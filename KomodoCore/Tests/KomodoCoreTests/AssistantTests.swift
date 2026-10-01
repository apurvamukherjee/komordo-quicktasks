import Foundation
import Testing

@testable import KomodoCore

struct AssistantTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    // Thursday 1 October 2026, 14:14 UTC.
    private let now = Date(timeIntervalSince1970: 1_790_864_040)
    private var today: LocalDate { LocalDate(now, calendar: calendar) }

    private let personal = TaskList(id: "personal", name: "Personal", color: "teal")
    private let work = TaskList(id: "work", name: "Work", color: "lime")

    private var context: AssistantContext {
        AssistantContext(
            lists: [personal, work],
            tasks: [
                TaskItem(id: "accounts", listID: "work", title: "Review accounts", bucket: .today, rank: 1),
                TaskItem(id: "gym", listID: "personal", title: "Gym", bucket: .week, rank: 1, estimate: 3_600),
            ],
            defaultListID: "personal", week: WeekRange(containing: today, calendar: calendar), now: now,
            calendar: calendar)
    }

    @Test func daysAsPeopleSayThem() {
        func day(_ phrase: String) -> String? { DayPhrase.day(phrase, today: today, calendar: calendar)?.description }
        #expect(day("today") == "2026-10-01")
        #expect(day("Tomorrow") == "2026-10-02")
        #expect(day("fri") == "2026-10-02")
        #expect(day("by Friday") == "2026-10-02")
        #expect(day("thu") == "2026-10-01")
        #expect(day("next thursday") == "2026-10-08")
        #expect(day("next week") == "2026-10-05")
        #expect(day("in 3 days") == "2026-10-04")
        #expect(day("2026-12-24") == "2026-12-24")
        #expect(day("someday") == nil)
    }

    @Test func timesAsPeopleSayThem() {
        #expect(DayPhrase.minute("07:00") == 420)
        #expect(DayPhrase.minute("7") == 420)
        #expect(DayPhrase.minute("7pm") == 1_140)
        #expect(DayPhrase.minute("7:30 PM") == 1_170)
        #expect(DayPhrase.minute("12am") == 0)
        #expect(DayPhrase.minute("12pm") == 720)
        #expect(DayPhrase.minute("noon") == 720)
        #expect(DayPhrase.minute("25:00") == nil)
        #expect(DayPhrase.minute("13pm") == nil)
    }

    /// Assistant.png's brain dump: "tomorrow gym 1h at 7, finish the deck by Fri (3h), call Apurva".
    @Test func aBrainDumpBecomesAPreview() throws {
        let plan = AssistantPlan(
            reply: "Here are 3 tasks.",
            add: [
                .init(title: "Gym", day: "tomorrow", time: "07:00", estimateMinutes: 60),
                .init(title: "Finish the deck", list: "work", day: "fri", estimateMinutes: 180),
                .init(title: "Call Apurva 15m"),
            ])
        let result = AssistantResolver.resolve(plan, in: context)
        #expect(result.problems.isEmpty)
        let tasks = result.proposals.map(\.task)
        #expect(tasks.map(\.title) == ["Gym", "Finish the deck", "Call Apurva"])
        #expect(tasks.map(\.listID) == ["personal", "work", "personal"])
        #expect(tasks[0].scheduledDate?.description == "2026-10-02")
        #expect(tasks[0].scheduledMinute == 420)
        #expect(tasks[0].estimate == 3_600)
        #expect(tasks[2].estimate == 900)
        #expect(tasks[2].column(in: context.week) == .today)
        #expect(tasks[2].rank == 2)
        #expect(result.proposals.allSatisfy { $0.kind == .add && $0.isIncluded })
    }

    @Test func editsFindTheirTaskByName() throws {
        let plan = AssistantPlan(
            reply: "Moved and logged.",
            edit: [
                .init(task: "@Review accounts", day: "tomorrow"),
                .init(task: "gym", logMinutes: 30),
                .init(task: "@Dentist", done: true),
            ])
        let result = AssistantResolver.resolve(plan, in: context)
        #expect(result.problems == ["Couldn't find @Dentist."])
        let moved = try #require(result.proposals.first)
        #expect(moved.kind == .edit(before: context.tasks[0]))
        #expect(moved.task.scheduledDate?.description == "2026-10-02")
        #expect(moved.task.column(in: context.week) == .week)
        let logged = try #require(result.proposals.last)
        #expect(logged.loggedMinutes == 30)
        #expect(logged.task.timeTaken(at: now) == 1_800)
    }

    @Test func aChangeThatChangesNothingIsLeftOut() {
        let result = AssistantResolver.resolve(
            AssistantPlan(reply: "", edit: [.init(task: "Gym", estimateMinutes: 60)]), in: context)
        #expect(result.proposals.isEmpty)
    }

    @Test func thePlanDecodesFromTheSchemasShape() throws {
        let json = """
            {"reply":"OK","add":[{"title":"Gym","list":null,"day":"tomorrow","time":"7am","estimate_minutes":60,
            "notes":null,"subtasks":[]}],"edit":[{"task":"Gym","title":null,"list":null,"column":"today",
            "day":null,"time":null,"estimate_minutes":null,"notes":null,"add_subtasks":[],"log_minutes":15,
            "done":null}]}
            """
        let plan = try JSONDecoder().decode(AssistantPlan.self, from: Data(json.utf8))
        #expect(plan.add.first?.estimateMinutes == 60)
        #expect(plan.edit.first?.logMinutes == 15)
        #expect(AssistantPlan.jsonSchema["required"] == ["reply", "add", "edit"])
    }

    @Test func thePromptCarriesTheBoard() {
        let prompt = AssistantPrompt.instructions(for: context)
        #expect(prompt.contains("Today is Thursday, 2026-10-01."))
        #expect(prompt.contains("Lists: Personal, Work."))
        #expect(prompt.contains("- Review accounts [Work, today]"))
    }
}
