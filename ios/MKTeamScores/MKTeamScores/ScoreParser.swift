import Foundation

struct ParsedRow: Equatable {
    var name: String
    var score: Int
}

/// Turns text lines read from a results screen into player names and running totals.
enum ScoreParser {

    static func parse(lines: [String]) -> [ParsedRow] {
        lines.compactMap(parseLine)
    }

    /// Example inputs: "1 AB Luigi +15 98", "12th [XY]Mario 7 140".
    /// The running total is the last plain number on the line; "+N" race points are ignored.
    static func parseLine(_ raw: String) -> ParsedRow? {
        var line = raw
        for ch in ["|", "¦", "_", "~", "`", "\"", "“", "”"] {
            line = line.replacingOccurrences(of: ch, with: " ")
        }
        var tokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !tokens.isEmpty else { return nil }

        var scoreIndex = -1
        var score = 0
        for i in stride(from: tokens.count - 1, through: 0, by: -1) {
            let original = tokens[i]
            if original.hasPrefix("+") { continue }
            var t = original
                .replacingOccurrences(of: "o", with: "0")
                .replacingOccurrences(of: "O", with: "0")
                .replacingOccurrences(of: "l", with: "1")
                .replacingOccurrences(of: "I", with: "1")
            while let last = t.last, ".,:;".contains(last) { t.removeLast() }
            if (1...3).contains(t.count), t.allSatisfy(\.isASCIIDigitChar), let v = Int(t) {
                scoreIndex = i
                score = v
                break
            }
        }
        guard scoreIndex >= 1 else { return nil }

        var nameTokens = Array(tokens[..<scoreIndex]).filter { !isRacePoints($0) }
        if nameTokens.count > 1, isPlacement(nameTokens[0]) { nameTokens.removeFirst() }
        while nameTokens.count > 1, isStrayNumber(nameTokens[nameTokens.count - 1]) { nameTokens.removeLast() }
        tokens = nameTokens

        var name = tokens.joined(separator: " ")
        // Trim junk around the name but keep brackets that may wrap a tag.
        while let f = name.first, !(f.isLetter || f.isNumber || f == "[" || f == "(") { name.removeFirst() }
        while let l = name.last, !(l.isLetter || l.isNumber || l == "]" || l == ")") { name.removeLast() }
        name = name.trimmingCharacters(in: .whitespaces)

        guard name.count >= 2, name.contains(where: \.isLetter) else { return nil }
        return ParsedRow(name: name, score: score)
    }

    private static func isRacePoints(_ t: String) -> Bool {
        t.hasPrefix("+") && t.count > 1 && t.dropFirst().allSatisfy(\.isASCIIDigitChar)
    }

    private static func isPlacement(_ t: String) -> Bool {
        t.range(of: #"^\d{1,2}(st|nd|rd|th)?[.)]?$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func isStrayNumber(_ t: String) -> Bool {
        t.range(of: #"^[+\-]?\d{1,2}$"#, options: .regularExpression) != nil
    }

    /// Same player appearing in two overlapping photos: keep the later reading.
    static func dedupe(_ rows: [ParsedRow]) -> [ParsedRow] {
        var out: [ParsedRow] = []
        for r in rows {
            let k = normKey(r.name)
            if let i = out.firstIndex(where: { similarity(normKey($0.name), k) >= 0.8 }) {
                out[i].score = r.score
            } else {
                out.append(r)
            }
        }
        return out
    }

    static func normKey(_ s: String) -> String {
        String(s.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    /// 1 - normalised Levenshtein distance.
    static func similarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1 }
        let a = Array(a), b = Array(b)
        if a.isEmpty || b.isEmpty { return 0 }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return 1 - Double(prev[b.count]) / Double(max(a.count, b.count))
    }
}

private extension Character {
    var isASCIIDigitChar: Bool { ("0"..."9").contains(self) }
}
