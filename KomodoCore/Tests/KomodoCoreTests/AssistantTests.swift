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
        let result = AssistantResolver.resolve(
            plan, for: "tomorrow gym 1h at 7, finish the deck for work by Fri (3h), call Apurva 15m", in: context)
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
        let result = AssistantResolver.resolve(
            plan, for: "move @Review accounts to tomorrow, log 30min on gym, @dentist is done", in: context)
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
            AssistantPlan(reply: "", edit: [.init(task: "Gym", estimateMinutes: 60)]), for: "gym is 1h", in: context)
        #expect(result.proposals.isEmpty)
    }

    @Test func aMidnightNobodyAskedForIsDropped() {
        let plan = AssistantPlan(reply: "", add: [.init(title: "Finish the deck", day: "fri", time: "00:00")])
        let deck = AssistantResolver.resolve(plan, for: "finish the deck by Fri", in: context).proposals.first?.task
        #expect(deck?.scheduledDate?.description == "2026-10-02")
        #expect(deck?.scheduledMinute == nil)
        let late = AssistantResolver.resolve(plan, for: "finish the deck by midnight fri", in: context)
        #expect(late.proposals.first?.task.scheduledMinute == 0)
    }

    /// What the on-device model did on its third try: Fri's deck went to tomorrow and the call got 30 min.
    @Test func eachTaskTakesItsValuesFromItsOwnPhrase() {
        let plan = AssistantPlan(
            reply: "",
            add: [
                .init(title: "Gym", day: "tomorrow", time: "07:00", estimateMinutes: 60),
                .init(title: "Deck", day: "tomorrow", estimateMinutes: 180),
                .init(title: "Call Apurva", day: "tomorrow", estimateMinutes: 30),
            ])
        let tasks = AssistantResolver.resolve(
            plan, for: "tomorrow gym 1h at 7, finish the deck by Fri (3h), call Apurva", in: context
        ).proposals.map(\.task)
        #expect(tasks.map { $0.scheduledDate?.description } == ["2026-10-02", "2026-10-02", nil])
        #expect(tasks.map(\.scheduledMinute) == [420, nil, nil])
        #expect(tasks.map(\.estimate) == [3_600, 10_800, nil])
    }

    /// The on-device model sometimes leaves a phrase out; it comes back as its own task.
    @Test func aBrainDumpNeverLosesAnItem() {
        let plan = AssistantPlan(reply: "", add: [.init(title: "Gym"), .init(title: "Finish Deck")])
        let tasks = AssistantResolver.resolve(
            plan, for: "tomorrow gym 1h at 7, finish the deck by Fri (3h), call Apurva at 4pm", in: context
        ).proposals.map(\.task)
        #expect(tasks.map(\.title) == ["Gym", "Finish Deck", "Call Apurva"])
        #expect(tasks.last?.scheduledMinute == 16 * 60)
        // Not a brain dump: a question gets an answer, not a task.
        let question = AssistantResolver.resolve(AssistantPlan(reply: "Two."), for: "what's left today?", in: context)
        #expect(question.proposals.isEmpty)
    }

    /// What the on-device model did with "move @Draft launch email to tomorrow and log 30min on @Plan the
    /// offsite": a bracketed copy as a new task, a rename, a move to Backlog, and no time logged.
    @Test func atCommandsAreReadFromTheWords() throws {
        var board = context
        board.tasks.append(TaskItem(id: "offsite", listID: "work", title: "Plan the offsite", bucket: .week, rank: 2))
        board.tasks.append(TaskItem(id: "plan", listID: "work", title: "Plan", bucket: .week, rank: 3))
        let garbled = AssistantPlan(
            reply: "",
            add: [.init(title: "Review accounts [Work, tomorrow]")],
            edit: [.init(task: "Review accounts", title: "Review accounts [Work, tomorrow]", column: "backlog")])
        let result = AssistantResolver.resolve(
            garbled, for: "move @Review accounts to tomorrow and log 30min on @Plan the offsite", in: board)
        #expect(result.proposals.count == 2)
        let moved = try #require(result.proposals.first { $0.id == "accounts" })
        #expect(moved.task.title == "Review accounts")
        #expect(moved.task.scheduledDate?.description == "2026-10-02")
        let logged = try #require(result.proposals.first { $0.id == "offsite" })
        #expect(logged.loggedMinutes == 30)
    }

    @Test func atCommandsCoverDoneRenameAndColumns() {
        let none = AssistantPlan(reply: "")
        let done = AssistantResolver.resolve(none, for: "@gym is done", in: context).proposals.first
        #expect(done?.task.isDone == true)
        let renamed = AssistantResolver.resolve(none, for: "rename @Gym to Leg day", in: context).proposals.first
        #expect(renamed?.task.title == "Leg day")
        let parked = AssistantResolver.resolve(none, for: "move @Review accounts to backlog", in: context)
        #expect(parked.proposals.first?.task.column(in: context.week) == .backlog)
    }

    @Test func phrasesBecomeTitles() {
        let titles = RequestPhrase.split("finish the deck by Fri (3h), Lunch with Apurva next fri at 1pm, gym 1.5h")
            .map(\.title)
        #expect(titles == ["Finish the deck", "Lunch with Apurva", "Gym"])
    }

    @Test func phrasesSayTheirOwnDayTimeAndLength() {
        let phrases = RequestPhrase.split("Lunch with Apurva next fri at 1pm and review notes for 45 min; gym 1.5h")
        #expect(phrases.map(\.day) == ["next fri", nil, nil])
        #expect(phrases.map(\.minute) == [780, nil, nil])
        #expect(phrases.map(\.minutes) == [nil, 45, 90])
    }

    /// The on-device model filled in a 10:00 AM, a 30 min estimate and a list nobody gave.
    @Test func valuesTheUserDidntGiveAreDropped() throws {
        let plan = AssistantPlan(
            reply: "",
            add: [.init(title: "Call Apurva", list: "work", day: "today", time: "10:00", estimateMinutes: 30)])
        let call = try #require(AssistantResolver.resolve(plan, for: "call Apurva", in: context).proposals.first?.task)
        #expect(call.listID == "personal")
        #expect(call.scheduledDate == nil)
        #expect(call.scheduledMinute == nil)
        #expect(call.estimate == nil)
        let given = try #require(
            AssistantResolver.resolve(plan, for: "call Apurva today at 10 for 30 min, work", in: context)
                .proposals.first?.task)
        #expect(given.listID == "work")
        #expect(given.scheduledMinute == 600)
        #expect(given.estimate == 1_800)
    }

    /// What the on-device model did with Assistant.png's brain dump: it renamed tasks nobody mentioned.
    @Test func changesToTasksTheUserDidntNameAreDropped() {
        let plan = AssistantPlan(
            reply: "", add: [.init(title: "Gym")],
            edit: [.init(task: "Review accounts", title: "Finish the deck", day: "today")])
        let result = AssistantResolver.resolve(plan, for: "gym tomorrow, finish the deck", in: context)
        // The phrase the bad edit stood for comes back as a new task.
        #expect(result.proposals.map(\.task.title) == ["Gym", "Finish the deck"])
        #expect(result.proposals.allSatisfy { $0.kind == .add })
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
        let dump = AssistantPrompt.instructions(for: context, request: "gym tomorrow, call Apurva")
        #expect(dump.contains("Today is Thursday, 2026-10-01."))
        #expect(dump.contains("Lists: Personal, Work."))
        #expect(dump.contains("- \"Gym\" in Personal"))
        #expect(!dump.contains("- \"Review accounts\""))
        let mention = AssistantPrompt.instructions(for: context, request: "move @review to friday")
        #expect(mention.contains("- \"Review accounts\" in Work"))
    }
}
