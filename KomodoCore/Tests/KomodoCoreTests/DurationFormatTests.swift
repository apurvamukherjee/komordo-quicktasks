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

    @Test func hoursMinutesPadsBothFields() {
        #expect(DurationFormat.hoursMinutes(0) == "00:00")
        #expect(DurationFormat.hoursMinutes(5_400) == "01:30")
        #expect(DurationFormat.hoursMinutes(36_000) == "10:00")
    }

    @Test(
        arguments: [
            ("1:30", 5_400),
            ("01:30", 5_400),
            (" 0:45 ", 2_700),
            ("45", 2_700),
            ("0", 0),
        ] as [(String, TimeInterval)])
    func parsesValidInput(text: String, expected: TimeInterval) {
        #expect(DurationFormat.parseHoursMinutes(text) == expected)
    }

    @Test(arguments: ["", "1:5", "1:60", "a:30", "1:30:00", "-5", "1:-1"])
    func rejectsInvalidInput(text: String) {
        #expect(DurationFormat.parseHoursMinutes(text) == nil)
    }
}
