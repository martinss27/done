import Foundation
import Observation
import UIKit

/// Bugs and ideas sent from Settings become issues on the public repo. There
/// is no server: the token ships inside the app, scoped to issues on this one
/// repo, so the worst a pulled-apart copy can do is file issues.
@MainActor
@Observable
final class Feedback {
    struct Report: Codable, Identifiable, Equatable {
        var number: Int
        var title: String
        var isIdea: Bool
        var date: Date
        var isOpen = true

        var id: Int { number }
        var url: URL { URL(string: "https://github.com/\(Feedback.repo)/issues/\(number)")! }
    }

    enum Failure: LocalizedError {
        case noToken, rejected, status(Int)

        var errorDescription: String? {
            switch self {
            case .noToken: "This build has no GitHub token. See the README."
            case .rejected: "GitHub rejected the token. It may have expired."
            case .status(let code): "GitHub answered \(code). Try again in a moment."
            }
        }
    }

    nonisolated static let repo = "martinss27/done"

    private(set) var reports = Storage.load([Report].self, Storage.Key.reports) ?? [] {
        didSet { Storage.save(reports, Storage.Key.reports) }
    }

    var openCount: Int { reports.filter(\.isOpen).count }

    private var token: String { Bundle.main.object(forInfoDictionaryKey: "GitHubToken") as? String ?? "" }

    /// The first line is the title. A first line too long for a title is cut,
    /// and then the body keeps the whole text so nothing is lost.
    nonisolated static func split(_ text: String) -> (title: String, body: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.split(separator: "\n", maxSplits: 1)
        let first = lines.first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        guard first.count <= 80 else { return (first.prefix(80) + "…", trimmed) }
        let rest = lines.count > 1 ? lines[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return (first, rest)
    }

    func send(_ text: String, isIdea: Bool) async throws {
        guard !token.isEmpty else { throw Failure.noToken }
        let (title, body) = Self.split(text)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let device = UIDevice.current
        let issue = NewIssue(
            title: title,
            body: body + "\n\n---\nSent from the Done app · \(device.systemName) \(device.systemVersion) · Done \(version)",
            labels: [isIdea ? "enhancement" : "bug"])

        var request = request("issues")
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(issue)
        let created: Issue = try await fetch(request)
        reports.insert(Report(number: created.number, title: title, isIdea: isIdea, date: .now), at: 0)
    }

    /// A closed issue shows as fixed. Failures keep the last known status.
    // ponytail: one request per report, fine for dozens; use the list endpoint if it grows.
    func refresh() async {
        for number in reports.map(\.number) {
            guard let issue: Issue = try? await fetch(request("issues/\(number)")),
                  let i = reports.firstIndex(where: { $0.number == number }) else { continue }
            if reports[i].isOpen != (issue.state == "open") { reports[i].isOpen.toggle() }
        }
    }

    private struct NewIssue: Encodable { var title, body: String; var labels: [String] }
    private struct Issue: Decodable { var number: Int; var state: String }

    private func request(_ path: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/\(path)")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // The repo is public, so reading status still works without a token.
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func fetch<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw Failure.rejected }
        guard (200..<300).contains(code) else { throw Failure.status(code) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
