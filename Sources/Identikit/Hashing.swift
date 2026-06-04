//
// Hash resolution and hex parsing. Jdenticon hashes the input value with SHA-1
// (here via CryptoKit's `Insecure.SHA1`, so no third-party crypto dependency)
// unless the value is already a valid hash (11+ hex characters), in which case
// it is used verbatim. `parseHex` reproduces JavaScript's `parseInt(substr,16)`
// including negative `substr` start positions.
//

import CryptoKit
import Foundation

/// Hashing and hex-extraction helpers shared by identicon styles.
public enum IdenticonHasher {
    /// Returns true if `candidate` is a usable precomputed hash: 11 or more
    /// hexadecimal characters. Mirrors Jdenticon's `isValidHash`.
    public static func isValidHash(_ candidate: String) -> Bool {
        guard candidate.count >= 11 else { return false }
        return candidate.utf8.allSatisfy { byte in
            (byte >= 0x30 && byte <= 0x39)  // 0-9
                || (byte >= 0x61 && byte <= 0x66)  // a-f
                || (byte >= 0x41 && byte <= 0x46)  // A-F
        }
    }

    /// Resolves an arbitrary input value to a hash string: the value itself if
    /// it is already a valid hash, otherwise its SHA-1 hex digest.
    public static func resolve(_ value: String) -> String {
        isValidHash(value) ? value : sha1Hex(value)
    }

    /// Lowercase hex SHA-1 digest of a string's UTF-8 bytes.
    public static func sha1Hex(_ value: String) -> String {
        Insecure.SHA1.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Parses `octets` hex characters of `hash` starting at `start` as an
    /// integer. A negative `start` counts from the end and an omitted `octets`
    /// reads to the end of the string — both matching JavaScript `substr`.
    static func parseHex(_ hash: String, _ start: Int, _ octets: Int? = nil) -> Int {
        let slice = substr(hash, start, octets)
        return Int(slice, radix: 16) ?? 0
    }

    /// Reproduces `String.prototype.substr(start, length)` for the ASCII hex
    /// strings used here.
    static func substr(_ string: String, _ start: Int, _ length: Int?) -> String {
        let chars = Array(string)
        let count = chars.count
        var begin = start
        if begin < 0 { begin = max(count + begin, 0) }
        if begin >= count { return "" }
        let available = count - begin
        let take: Int
        if let length { take = max(0, min(length, available)) } else { take = available }
        guard take > 0 else { return "" }
        return String(chars[begin..<begin + take])
    }
}
