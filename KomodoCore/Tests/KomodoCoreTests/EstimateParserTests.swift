import Foundation
import Testing

@testable import KomodoCore

struct EstimateParserTests {
    @Test(
        arguments: [
            ("Write spec 45m", "Write spec", 2_700),
            ("Email campaign 2hr 15min", "Email campaign", 8_100),
            ("Deep work 2h", "Deep work", 7_200),
            ("Deep work 2hr", "Deep work", 7_200),
            ("Deep work 2 hrs", "Deep work", 7_200),
            ("Review 90m", "Review", 5_400),
            ("Review 90min", "Review", 5_400),
            ("Review 1h30", "Review", 5_400),
            ("Review 1:30", "Review", 5_400),
            ("Review 1.5h", "Review", 5_400),
        ] as [(String, String, TimeInterval)])
    func readsTrailingEstimates(input: String, title: String, estimate: TimeInterval) {
        #expect(EstimateParser.parse(input) == .init(title: title, estimate: estimate))
    }

    @Test(arguments: ["Read 2 chapters", "Call the bank", "2h", "Fix bug #42", "Plan 2h trip"])
    func leavesOtherTitlesAlone(input: String) {
        #expect(EstimateParser.parse(input) == .init(title: input, estimate: nil))
    }
}
