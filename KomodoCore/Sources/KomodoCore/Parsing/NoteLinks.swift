import Foundation

/// Finds the links in a task's notes. Only `http` and `https` count, because those are the only ones Komodo
/// opens in the browser (FEATURES §4.5).
public enum NoteLinks {
    public static func find(in text: String) -> [URL] {
        guard !text.isEmpty,
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return [] }
        var seen = Set<URL>()
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let url = match.url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                seen.insert(url).inserted
            else { return nil }
            return url
        }
    }
}
