import Foundation

package final class CodexBarLockedState<State>: @unchecked Sendable {
    private let lock = NSLock()
    private var state: State

    package init(initialState: State) {
        self.state = initialState
    }

    package func withLock<Result>(_ body: (inout State) throws -> Result) rethrows -> Result {
        self.lock.lock()
        defer { self.lock.unlock() }
        return try body(&self.state)
    }
}

package enum CodexBarCompat {
    package static func nanoseconds(_ seconds: TimeInterval) -> UInt64 {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return UInt64(min(seconds * 1_000_000_000, Double(UInt64.max)))
    }

    package static func sleep(seconds: TimeInterval) async throws {
        let nanoseconds = self.nanoseconds(seconds)
        if nanoseconds > 0 {
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    package static func regexCaptureGroups(in text: String, pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, range: range).map { match in
            (1..<match.numberOfRanges).compactMap { index in
                let range = match.range(at: index)
                guard range.location != NSNotFound else { return nil }
                return nsText.substring(with: range)
            }
        }
    }
}

extension URL {
    package func codexBarAppendingPath(_ path: String) -> URL {
        self.appendingPathComponent(path)
    }

    package func codexBarAppending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        var existingItems = components.queryItems ?? []
        existingItems.append(contentsOf: queryItems)
        components.queryItems = existingItems
        return components.url ?? self
    }

    package func codexBarHost(percentEncoded: Bool) -> String? {
        guard percentEncoded else { return self.host }
        return URLComponents(url: self, resolvingAgainstBaseURL: false)?.percentEncodedHost ?? self.host
    }
}

extension StringProtocol {
    package func codexBarTrimmingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return String(self) }
        return String(self.dropFirst(prefix.count))
    }
}
