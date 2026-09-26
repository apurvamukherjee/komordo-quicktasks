import Foundation
import Testing

@testable import KomodoCore

struct DurationFormatTests {
    // Literal seconds keep the argument list cheap for the type checker.
    @Test(
        arguments: [
            (0, "0min"),
            (20, "0min"),
            (2_700, "45min"),
            (3_600, "1hr"),
            (9_000, "2hr 30min"),
            (5_429, "1hr 30min"),
            (5_431, "1hr 31min"),
            (-120, "0min"),
        ] as [(TimeInterval, String)])
    func short(seconds: TimeInterval, expected: String) {
        #expect(DurationFormat.short(seconds) == expected)
    }
}
