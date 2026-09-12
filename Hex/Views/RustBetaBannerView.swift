import Darwin
import SwiftUI

enum RustBetaAnnouncement {
	static let downloadURL = URL(string: "https://hex.kitlangton.com")!
	/// Septa is not Hex's Rust beta. Keep the type so existing tests compile,
	/// but never show the banner in the app.
	static let isAvailable = false

	static func isSupported(macOSMajorVersion: Int, appleSilicon: Bool) -> Bool {
		macOSMajorVersion >= 15 && appleSilicon
	}
}

struct RustBetaBannerView: View {
	let dismiss: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 8) {
				Image(systemName: "hexagon.fill")
					.font(.system(size: 17))
					.foregroundStyle(Color.accentColor)
					.accessibilityHidden(true)
				Text("Meet the new Hex")
					.font(.system(size: 13, weight: .semibold))
				Text("BETA")
					.font(.system(size: 9, weight: .semibold))
					.foregroundStyle(Color.accentColor)
					.padding(.horizontal, 6)
					.padding(.vertical, 3)
					.background(Color.accentColor.opacity(0.1), in: Capsule())
				Spacer(minLength: 0)
				Button(action: dismiss) {
					Image(systemName: "xmark")
						.font(.system(size: 10, weight: .semibold))
						.foregroundStyle(.secondary)
						.frame(width: 24, height: 24)
						.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.help("Dismiss beta announcement")
				.accessibilityLabel("Dismiss beta announcement")
				.accessibilityIdentifier("dismiss-rust-beta-banner")
			}

			Text("I rewrote Hex in Rust. Try the beta and tell me what you think.")
				.font(.system(size: 12))
				.fixedSize(horizontal: false, vertical: true)

			Link(destination: RustBetaAnnouncement.downloadURL) {
				Label("Try the beta", systemImage: "arrow.up.right")
			}
			.buttonStyle(.bordered)
			.controlSize(.small)
			.accessibilityIdentifier("open-rust-beta")
		}
		.padding(.vertical, 4)
		.accessibilityElement(children: .contain)
	}
}

#Preview {
	Form {
		Section {
			RustBetaBannerView(dismiss: {})
		}
	}
	.formStyle(.grouped)
	.frame(width: 460, height: 210)
}
