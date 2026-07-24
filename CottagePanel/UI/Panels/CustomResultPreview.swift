import AppKit
import Foundation
import KeyboardShortcuts
import SwiftUI

struct CustomResultPreview: View {
    let customAction: CustomAction?
    let result: CustomActionResult?
    @ObservedObject var state: CottageState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 0).id("custom-preview-top")
                    if let customAction {
                        header(customAction)
                        Divider()
                    }

                    if let result {
                        resultDetails(result)
                    } else {
                        Text(L10n.text("custom.result.empty"))
                            .foregroundStyle(.secondary)
                    }

                    Color.clear.frame(height: 0).id("custom-preview-bottom")
                    Spacer()
                }
                .padding(16)
            }
            .onReceive(NotificationCenter.default.publisher(for: .cottagePreviewScrollCommand)) { notification in
                guard let command = notification.cottagePreviewCommand else {
                    return
                }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(
                        command == .scrollUp ? "custom-preview-top" : "custom-preview-bottom",
                        anchor: .center
                    )
                }
            }
        }
    }

    private func header(_ customAction: CustomAction) -> some View {
        HStack(spacing: 10) {
            if let icon = customAction.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: customAction.symbolName)
                    .font(.title2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(customAction.definition.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(customAction.definition.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
    }

    private func resultDetails(_ result: CustomActionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
            if !result.subtitle.isEmpty {
                Text(result.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            if let previewImagePath = result.previewImagePath {
                previewImage(previewImagePath)
            }
            if !result.text.isEmpty {
                previewText(result.text)
            }
            if let shortcutName = state.settingsShortcutName(for: result) {
                shortcutRecorder(shortcutName, result: result)
            }
            if !result.tags.isEmpty {
                Text(L10n.text("preview.tags"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(result.tags.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            if !result.metadata.isEmpty {
                metadata(result.metadata)
            }
        }
    }

    private func shortcutRecorder(
        _ shortcutName: KeyboardShortcuts.Name,
        result: CustomActionResult
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("settings.shortcut.recordInPanel"))
                .font(.caption)
                .foregroundStyle(.secondary)
            SettingsShortcutRecorderView(
                name: shortcutName,
                focusTrigger: state.shortcutRecorderFocusTrigger(for: result)
            ) {
                state.refreshBuiltInSettingsResults()
            }
            .frame(width: 180)
        }
    }

    @ViewBuilder
    private func previewImage(_ path: String) -> some View {
        let expandedPath = NSString(string: path).expandingTildeInPath
        if let image = NSImage(contentsOfFile: expandedPath) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260, maxHeight: 260)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func metadata(_ items: [CustomResultMetadata]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            ForEach(items) { item in
                HStack(alignment: .top) {
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 76, alignment: .leading)
                    metadataValue(item)
                }
            }
        }
    }

    @ViewBuilder
    private func metadataValue(_ item: CustomResultMetadata) -> some View {
        if item.type == "link",
           let urlString = item.url,
           let url = URL(string: urlString),
           ["http", "https", "file"].contains(url.scheme) {
            Link(item.value, destination: url)
                .font(.caption)
        } else {
            Text(item.value)
                .font(item.type == "code" ? .system(.caption, design: .monospaced) : .caption)
                .textSelection(.enabled)
                .lineLimit(3)
                .truncationMode(.tail)
        }
    }

    @ViewBuilder
    private func previewText(_ text: String) -> some View {
        switch customAction?.definition.preview.style ?? .text {
        case .text:
            Text(text)
                .font(.body)
                .textSelection(.enabled)
        case .json:
            Text(formattedJSON(text))
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        case .markdown:
            if let attributedString = try? AttributedString(markdown: text) {
                Text(attributedString)
                    .textSelection(.enabled)
            } else {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
    }

    private func formattedJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let formattedData = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.prettyPrinted, .sortedKeys]
              ),
              let formattedText = String(data: formattedData, encoding: .utf8) else {
            return text
        }

        return formattedText
    }
}
