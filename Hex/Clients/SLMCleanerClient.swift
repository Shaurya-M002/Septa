import Foundation

/// Sends a finished transcript to Septa's local SLM sidecar (`POST /v1/clean`)
/// and returns the cleaned text.
///
/// This runs after ASR and after Hex's own word remapping, so it sees the same
/// string that is about to be pasted.
///
/// It **fails open**. If the sidecar is not running, is slow, or returns
/// anything unexpected, the original transcript is returned unchanged. Losing
/// someone's dictation because a side process was down is not an acceptable
/// trade for nicer punctuation.
enum SLMCleanerClient {
	struct Response: Decodable {
		let cleaned: String
		let violations: [Violation]

		struct Violation: Decodable {
			let kind: String
			let value: String
			let reason: String
		}
	}

	/// Default matches `sidecar/server/app.py`.
	static var endpoint: URL {
		let raw = ProcessInfo.processInfo.environment["SLM_CLEAN_URL"]
			?? "http://127.0.0.1:8742/v1/clean"
		return URL(string: raw) ?? URL(string: "http://127.0.0.1:8742/v1/clean")!
	}

	static var healthURL: URL {
		var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
		components?.path = "/healthz"
		return components?.url ?? URL(string: "http://127.0.0.1:8742/healthz")!
	}

	static var isEnabled: Bool {
		ProcessInfo.processInfo.environment["SLM_CLEAN_DISABLED"] == nil
	}

	static func isReachable() async -> Bool {
		var request = URLRequest(url: healthURL)
		request.timeoutInterval = 1
		do {
			let (_, response) = try await URLSession.shared.data(for: request)
			return (response as? HTTPURLResponse)?.statusCode == 200
		} catch {
			return false
		}
	}

	/// Hex has no notion of our styles yet, so everything is `chat` until there
	/// is a setting for it. `bullets` is the one worth wiring to a hotkey.
	static func clean(_ text: String, style: String = "chat") async -> String {
		guard isEnabled, !text.isEmpty else { return text }

		var request = URLRequest(url: endpoint)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.timeoutInterval = 3
		request.httpBody = try? JSONSerialization.data(
			withJSONObject: ["text": text, "style": style]
		)

		do {
			let (data, response) = try await URLSession.shared.data(for: request)
			guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
				return text
			}
			let decoded = try JSONDecoder().decode(Response.self, from: data)
			// An empty result is legitimate (filler-only speech), but only trust
			// it when the model also had nothing to refuse.
			if decoded.cleaned.isEmpty, !decoded.violations.isEmpty {
				return text
			}
			return decoded.cleaned
		} catch {
			return text
		}
	}
}
