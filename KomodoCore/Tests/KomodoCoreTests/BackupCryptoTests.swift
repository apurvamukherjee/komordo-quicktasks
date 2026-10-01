import Foundation
import Testing

@testable import KomodoCore

struct BackupCryptoTests {
    // Few rounds keep the suite fast; the file records its own rounds, so opening reads them back.
    private let rounds: UInt32 = 1_000
    private let zip = Data("PK zip bytes".utf8)

    @Test func theRightPasswordOpensTheSeal() throws {
        let sealed = try BackupCrypto.seal(zip, password: "réunion 🦎", rounds: rounds)
        #expect(BackupCrypto.isSealed(sealed))
        #expect(!sealed.contains(zip))
        #expect(try BackupCrypto.open(sealed, password: "réunion 🦎") == zip)
    }

    @Test func eachSealGetsItsOwnSalt() throws {
        let first = try BackupCrypto.seal(zip, password: "pw", rounds: rounds)
        let second = try BackupCrypto.seal(zip, password: "pw", rounds: rounds)
        #expect(first != second)
    }

    @Test func aWrongPasswordOrAChangedFileIsRefused() throws {
        let sealed = try BackupCrypto.seal(zip, password: "pw", rounds: rounds)
        #expect(throws: BackupError.wrongPassword) { try BackupCrypto.open(sealed, password: "Pw") }

        var flipped = sealed
        flipped[flipped.count - 1] ^= 1
        #expect(throws: BackupError.wrongPassword) { try BackupCrypto.open(flipped, password: "pw") }

        // Lowering the rounds in the header would make guessing cheaper; it's authenticated, so it fails.
        var weakened = sealed
        weakened[8] ^= 1
        #expect(throws: BackupError.wrongPassword) { try BackupCrypto.open(weakened, password: "pw") }
    }

    @Test func aZipIsntSealed() {
        #expect(!BackupCrypto.isSealed(zip))
        #expect(throws: BackupError.notABackup) { try BackupCrypto.open(zip, password: "pw") }
        #expect(throws: BackupError.notABackup) { try BackupCrypto.open(Data("KBAK".utf8), password: "pw") }
    }
}
