import Foundation

/// Result of parsing one QR payload such as
/// `code:88811300,boomName:香辣鸡翅(出水腌制),expirationTime:1794296940`
struct Parsed {
    var code: String
    var name: String
    var exp: Date
}

enum PayloadParser {

    static func parse(_ raw: String) -> Parsed? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        var code = ""
        var name = ""
        var exp: Date? = nil

        let normalized = s.replacingOccurrences(of: "：", with: ":")
        for part in normalized.components(separatedBy: ",") {
            let kv = part.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.count == 2 else { continue }
            let key = kv[0].trimmingCharacters(in: .whitespaces).lowercased()
            let val = kv[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "code":
                code = val
            case "boomname", "name":
                name = val
            case "expirationtime", "exp":
                if let t = Double(val) {
                    // 13 digits -> milliseconds
                    exp = Date(timeIntervalSince1970: t > 100_000_000_000 ? t / 1000.0 : t)
                }
            default:
                break
            }
        }

        if exp == nil {
            exp = parseLooseDate(normalized, name: &name, code: &code)
        }

        guard let e = exp else { return nil }
        var finalName = name
        if finalName.isEmpty { finalName = code }
        if finalName.isEmpty { finalName = "未命名" }

        // manual input like "88811300 香辣鸡翅 2026-11-11 23:59"
        if code.isEmpty {
            let head = finalName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if head.count == 2, head[0].count >= 6, Int(head[0]) != nil {
                code = String(head[0])
                finalName = String(head[1])
            }
        } else if finalName.hasPrefix(code) {
            finalName = String(finalName.dropFirst(code.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: " -–—::"))
        }

        return Parsed(code: code, name: finalName, exp: e)
    }

    /// fallback: any `20xx-mm-dd[ hh:mm]` inside the text
    private static func parseLooseDate(_ s: String, name: inout String, code: inout String) -> Date? {
        let pattern = "(20\\d{2})[-/.](\\d{1,2})[-/.](\\d{1,2})(?:[ T](\\d{1,2})[:：](\\d{2}))?"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }

        func group(_ i: Int) -> Int? {
            let r = m.range(at: i)
            guard r.location != NSNotFound, let v = Int(ns.substring(with: r)) else { return nil }
            return v
        }
        guard let y = group(1), let mo = group(2), let d = group(3) else { return nil }
        let h = group(4) ?? 23
        let mi = group(5) ?? 59

        var comps = DateComponents()
        comps.year = y; comps.month = mo; comps.day = d; comps.hour = h; comps.minute = mi
        let date = Calendar.current.date(from: comps)

        if name.isEmpty {
            let prefix = ns.substring(to: m.range.location).trimmingCharacters(in: .whitespaces)
            name = prefix
        }
        return date
    }
}
