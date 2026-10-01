import Foundation
import KomodoCore

/// Komodo Assistant's conversation (DESIGN_SYSTEM §13.26): what was asked, the brain's preview, and what was
/// applied. Nothing reaches the board until Add, and Undo takes it back.
@MainActor @Observable final class AssistantModel {
    enum Phase: Equatable {
        case empty
        case thinking
        case proposal
        case discarded
        case applied
        case failed(String)
    }

    var isOpen = false
    var draft = ""
    private(set) var phase = Phase.empty
    private(set) var prompt = ""
    private(set) var sentAt: Date?
    private(set) var brain: AssistantBrain?
    private(set) var reply = ""
    var proposals: [AssistantProposal] = []
    private(set) var problems: [String] = []
    /// What Add saved, for the applied card's chips.
    private(set) var applied: [AssistantProposal] = []

    @ObservationIgnored private var undo: (@MainActor () -> Void)?
    @ObservationIgnored private var request: Task<Void, Never>?

    var included: [AssistantProposal] { proposals.filter(\.isIncluded) }

    func send(_ text: String? = nil, store: BoardStore) {
        let text = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, phase != .thinking else { return }
        guard let brain = AssistantBrain.pick(store.settings) else {
            phase = .failed(AssistantError.noBrain.message)
            return
        }
        draft = ""
        prompt = text
        sentAt = store.now
        self.brain = brain
        proposals = []
        problems = []
        undo = nil
        phase = .thinking
        let context = AssistantContext(
            lists: store.lists, tasks: store.tasks, defaultListID: store.selectedListID ?? store.lists.first?.id,
            week: store.week, now: store.now, calendar: store.calendar)
        let settings = store.settings
        request = Task {
            do throws(AssistantError) {
                let plan = try await brain.plan(text, context: context, settings: settings)
                // Cancelled while thinking: the answer is no longer wanted.
                guard !Task.isCancelled else { return }
                let result = AssistantResolver.resolve(plan, for: text, in: context)
                reply = plan.reply
                proposals = result.proposals
                problems = result.problems
                phase = .proposal
                #if DEBUG
                    if UserDefaults.standard.bool(forKey: "assistantApply") { apply(store: store) }
                #endif
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(error.message)
            }
        }
    }

    func apply(store: BoardStore) {
        undo = store.applyAssistant(proposals)
        applied = included
        phase = .applied
    }

    func undoApplied() {
        undo?()
        undo = nil
        phase = .proposal
    }

    func discard() { phase = .discarded }

    func showAgain() { phase = .proposal }

    /// The stop button while thinking: the answer is dropped when it arrives.
    func cancel() {
        request?.cancel()
        phase = proposals.isEmpty ? .empty : .proposal
    }

    func update(_ id: String, _ change: (inout AssistantProposal) -> Void) {
        guard let index = proposals.firstIndex(where: { $0.id == id }) else { return }
        change(&proposals[index])
    }

    #if DEBUG
        /// Previews and `-assistantState` captures: a phase with Assistant.png's brain dump already answered.
        func stage(_ phase: Phase, prompt: String, reply: String, proposals: [AssistantProposal], brain: AssistantBrain)
        {
            self.phase = phase
            self.prompt = prompt
            self.reply = reply
            self.proposals = proposals
            self.applied = proposals.filter(\.isIncluded)
            self.brain = brain
            sentAt = Date()
        }
    #endif
}
