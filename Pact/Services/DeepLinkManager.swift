//
//  DeepLinkManager.swift
//  Pact
//
//  Central handling for invite deep links. Captures URLs from cold start
//  (launchOptions) and from application(_:open:url:options:) so PactApp
//  can process them reliably when the UI is ready.
//

import Foundation
import os.log

private let log = Logger(subsystem: "cmc.Pact", category: "DeepLink")

/// Invite deep link URL scheme and host. Supports:
/// - Path: pact://join/ABC123
/// - Query: pact://join?code=ABC123
enum DeepLinkConstants {
    static let scheme = "pact"
    static let joinHost = "join"
    /// Invite codes are 6 characters (backend uses 6-digit numeric).
    static let inviteCodeLength = 6
}

/// Parses an invite code from a join deep link URL.
/// Supports path (pact://join/CODE) and query (pact://join?code=CODE).
/// Returns nil if scheme/host don't match or code is invalid length.
func parseInviteCode(from url: URL) -> String? {
    guard url.scheme?.lowercased() == DeepLinkConstants.scheme,
          url.host?.lowercased() == DeepLinkConstants.joinHost else {
        return nil
    }

    // Query param: pact://join?code=ABC123
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let code = components.queryItems?.first(where: { $0.name.lowercased() == "code" })?.value,
       !code.isEmpty {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == DeepLinkConstants.inviteCodeLength {
            return trimmed
        }
    }

    // Path: pact://join/ABC123 — pathComponents is ["/", "ABC123"] so last is the code
    let pathComponents = url.pathComponents.filter { $0 != "/" }
    if let code = pathComponents.last, code.count == DeepLinkConstants.inviteCodeLength {
        return code
    }

    return nil
}

/// Returns true if the URL is a Pact join deep link (even if code is invalid).
func isJoinDeepLink(_ url: URL) -> Bool {
    url.scheme?.lowercased() == DeepLinkConstants.scheme
        && url.host?.lowercased() == DeepLinkConstants.joinHost
}

// MARK: - Pending launch URL (cold start / open from background)

/// Holds a URL that was delivered at launch or via application(_:open:url:options:)
/// so the SwiftUI app can process it once the view hierarchy is ready.
final class DeepLinkManager {
    static let shared = DeepLinkManager()

    private let queue = DispatchQueue(label: "cmc.Pact.DeepLinkManager", attributes: .concurrent)
    private var _pendingURL: URL?

    var pendingURL: URL? {
        queue.sync { _pendingURL }
    }

    /// Store a URL to be processed by PactApp (e.g. from cold start or open URL).
    func setPendingURL(_ url: URL?) {
        queue.async(flags: .barrier) { [weak self] in
            self?._pendingURL = url
            if let url = url {
                log.debug("Stored pending deep link: \(url.absoluteString)")
            }
        }
    }

    /// Take and clear the pending URL so it is processed exactly once.
    func consumePendingURL() -> URL? {
        queue.sync(flags: .barrier) {
            let url = _pendingURL
            _pendingURL = nil
            return url
        }
    }
}
