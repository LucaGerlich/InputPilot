import SwiftUI

/// Edit these to control what the About card shows publicly in a release.
/// Leave a link blank ("") to hide that row.
enum AboutInfo {
    static let developerName = "Luca Gerlich"
    static let location = "Frankfurt, Germany"
    static let copyrightYear = "2026"

    // Blank string = link hidden. Website stays hidden until the page exists.
    static let githubURL = "https://github.com/LucaGerlich/InputPilot"
    static let websiteURL = "https://inputpilot.lucagerlich.dev"
    static let supportEmail = ""

    /// Optional asset-catalog image name for the developer avatar.
    /// Add an image set with this name to show it; otherwise a symbol is used.
    static let avatarAssetName = "DeveloperAvatar"
}

struct AboutSection: View {
    var body: some View {
        Section("About") {
            appRow
            developerRow

            if !links.isEmpty {
                HStack(spacing: 16) {
                    ForEach(links, id: \.label) { link in
                        Link(link.label, destination: link.url)
                    }
                }
            }
        }
        Section {
            Text("© \(AboutInfo.copyrightYear) \(AboutInfo.developerName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
        }
    }

    private var appRow: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(appName)
                    .font(.headline)
                Text("Version \(appVersion) (\(appBuild))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var developerRow: some View {
        HStack(spacing: 12) {
            avatar
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(AboutInfo.developerName)
                    .font(.body.weight(.medium))
                Text(AboutInfo.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var avatar: some View {
        if let image = NSImage(named: AboutInfo.avatarAssetName) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }

    private struct AboutLink {
        let label: String
        let url: URL
    }

    private var links: [AboutLink] {
        var result: [AboutLink] = []
        if let url = url(from: AboutInfo.githubURL) {
            result.append(AboutLink(label: "GitHub", url: url))
        }
        if let url = url(from: AboutInfo.websiteURL) {
            result.append(AboutLink(label: "Website", url: url))
        }
        if !AboutInfo.supportEmail.isEmpty,
           let url = URL(string: "mailto:\(AboutInfo.supportEmail)") {
            result.append(AboutLink(label: "Email", url: url))
        }
        return result
    }

    private func url(from string: String) -> URL? {
        guard !string.isEmpty else { return nil }
        return URL(string: string)
    }

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "InputPilot"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
