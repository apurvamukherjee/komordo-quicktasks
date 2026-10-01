import CommonCrypto
import CryptoKit
import Foundation

/// A password-protected backup's `.kbak` wrapper (ARCHITECTURE §7): the zip sealed with AES-GCM under a key
/// derived from the password with PBKDF2-SHA256.
///
/// Layout: `KBAK`, a format byte, the rounds (UInt32, big-endian), a 16-byte salt, then AES-GCM's combined
/// nonce, ciphertext and tag. The header is authenticated too, so lowering the rounds breaks the seal.
public enum BackupCrypto {
    public static let fileExtension = "kbak"
    public static let defaultRounds: UInt32 = 600_000
    private static let magic = Data("KBAK".utf8)
    private static let format: UInt8 = 1
    private static let saltLength = 16
    private static var headerLength: Int { magic.count + 1 + 4 + saltLength }

    /// Whether `data` starts like a `.kbak`, whatever its file name says.
    public static func isSealed(_ data: Data) -> Bool { data.starts(with: magic) }

    // ponytail: the whole zip sits in memory; stream in chunks if backups ever reach hundreds of MB.
    public static func seal(_ data: Data, password: String, rounds: UInt32 = defaultRounds) throws -> Data {
        let salt = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
        var header = magic
        header.append(format)
        withUnsafeBytes(of: rounds.bigEndian) { header.append(contentsOf: $0) }
        header.append(salt)
        let key = try key(password, salt: salt, rounds: rounds)
        let box = try AES.GCM.seal(data, using: key, authenticating: header)
        guard let combined = box.combined else { throw BackupCryptoError.sealFailed }
        return header + combined
    }

    /// The zip inside a `.kbak`. AES-GCM can't tell a wrong password from a changed file, and a wrong password
    /// is far more likely, so both read as `.wrongPassword`.
    public static func open(_ data: Data, password: String) throws(BackupError) -> Data {
        guard isSealed(data), data.count > headerLength, data[data.startIndex + magic.count] == format else {
            throw .notABackup
        }
        let header = data.prefix(headerLength)
        let roundsStart = data.startIndex + magic.count + 1
        let rounds = data[roundsStart..<roundsStart + 4].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        let salt = data[(roundsStart + 4)..<(data.startIndex + headerLength)]
        do {
            let box = try AES.GCM.SealedBox(combined: data.dropFirst(headerLength))
            return try AES.GCM.open(box, using: key(password, salt: Data(salt), rounds: rounds), authenticating: header)
        } catch {
            throw .wrongPassword
        }
    }

    private static func key(_ password: String, salt: Data, rounds: UInt32) throws -> SymmetricKey {
        var key = Data(count: 32)
        let status = key.withUnsafeMutableBytes { keyBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2), password, password.utf8.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds,
                    keyBytes.bindMemory(to: UInt8.self).baseAddress, 32)
            }
        }
        guard status == kCCSuccess else { throw BackupCryptoError.keyDerivationFailed(status) }
        return SymmetricKey(data: key)
    }
}

/// CommonCrypto or CryptoKit refused to seal; nothing was written.
public enum BackupCryptoError: Error, Equatable, Sendable {
    case keyDerivationFailed(Int32)
    case sealFailed
}
