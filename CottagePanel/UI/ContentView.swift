import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var state: CottageState

    var body: some View {
        VStack(spacing: 0) {
            searchHeader

            Divider()

            if state.activeCustomAction == nil {
                MainActionPanel(state: state)
            } else {
                CustomActionPanel(state: state)
            }

            Divider()

            footer
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .frame(height: 38)
            .keyboardFocusBorder(state.keyboardContext == .footer)
        }
        .frame(width: state.panelWidth, height: state.panelHeight)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .ignoresSafeArea()
        .onAppear {
            state.reset()
        }
        .onExitCommand {
            state.handleEscape()
        }
        .onMoveCommand { direction in
            state.moveSelection(direction)
        }
        .sheet(isPresented: $state.showsCustomPopup) {
            CustomActionPopupView(state: state)
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            if let chip = state.queryChip, state.activeCustomAction == nil {
                Button {
                    state.removeQueryChip()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(chip.title)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            CustomSearchField(
                text: state.activeCustomAction == nil ? $state.query : $state.customQuery,
                placeholder: state.searchPlaceholder,
                focusTrigger: state.searchFocusTrigger,
                onBackspaceWhenEmpty: {
                    state.handleSearchBackspaceWhenEmpty()
                },
                onMoveDownWhenEmpty: {
                    state.moveSelection(.down)
                    return true
                },
                onDropText: { text in
                    state.acceptDroppedText(text)
                },
                onDropFiles: { urls in
                    state.acceptDroppedFiles(urls)
                },
                onSubmit: {
                    state.runSelection()
                }
            )

            if let accessory = state.activeCustomAction?.definition.searchAccessory,
               !accessory.items.isEmpty {
                Picker("", selection: $state.customAccessoryValue) {
                    ForEach(accessory.items) { item in
                        Text(item.title).tag(item.id)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
                .onChange(of: state.customAccessoryValue) { value in
                    state.updateSearchAccessory(value)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    private var footer: some View {
        ZStack {
            HStack {
                footerMenuButton
                Spacer()
                keyboardHints
            }

            Text(state.statusMessage)
                .lineLimit(1)
                .foregroundStyle(.primary)
                .opacity(state.statusMessage.isEmpty ? 0 : 0.72)
                .animation(.easeOut(duration: 0.15), value: state.statusMessage)
        }
    }

    @ViewBuilder
    private var footerMenuButton: some View {
        FooterMenuButton(state: state)
    }

    @ViewBuilder
    private var keyboardHints: some View {
        if state.showsKeyboardHints {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.arrow.down")
                Text(L10n.text("footer.select"))
                Image(systemName: "return")
                Text(L10n.text("footer.run"))
                Image(systemName: "escape")
                Text(L10n.text("footer.close"))
            }
        }
    }
}

struct ActionRow: View {
    let action: CottageAction
    @ObservedObject var state: CottageState

    var body: some View {
        HStack(spacing: 8) {
            Label {
                VStack(alignment: .leading) {
                    HStack(spacing: 5) {
                        if state.isFavorite(action) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                        }
                        Text(action.title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 180, alignment: .leading)
                    }
                    Text(action.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 220, alignment: .leading)
                }
            } icon: {
                ActionIcon(action: action)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            if let shortcutLabel = state.commandShortcutLabel(for: action) {
                Text(shortcutLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            ActionKindBadge(kind: action.kind, showsText: state.actionBadgesShowText)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            state.select(action)
        }
        .onTapGesture(count: 2) {
            state.run(action)
        }
        .overlay(
            RightClickView {
                state.select(action)
                state.showActionsForSelection()
            }
        )
        .popover(
            isPresented: Binding(
                get: {
                    state.showsActionPalette && state.selectedActionID == action.id
                },
                set: { isPresented in
                    if !isPresented {
                        state.hideActionPalette()
                    }
                }
            ),
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .trailing
        ) {
            ActionPalette(action: action, state: state)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .tag(action.id)
        .id(action.id)
        .onAppear {
            state.markActionVisible(action)
        }
        .onDisappear {
            state.markActionHidden(action)
        }
    }
}

struct ActionIcon: View {
    let action: CottageAction

    var body: some View {
        if let icon = action.icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: action.symbolName)
        }
    }
}

private struct ActionKindBadge: View {
    let kind: CottageActionKind
    let showsText: Bool

    var body: some View {
        if showsText {
            Text(kind.title)
                .lineLimit(1)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(kind.title)
        } else {
            Image(systemName: kind.symbolName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(kind.title)
        }
    }
}

struct ActionPreview: View {
    let action: CottageAction?
    let executionCount: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 0).id("preview-top")
                    if let action {
                        HStack(spacing: 10) {
                            ActionIcon(action: action)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(action.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        Divider()

                        Text(L10n.text("preview.description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(action.subtitle)
                            .font(.body)
                            .lineLimit(2)
                            .truncationMode(.tail)

                        if !action.tags.isEmpty {
                            Text(L10n.text("preview.tags"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(action.tags.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.tail)
                        }

                        Text(String(format: L10n.text("preview.executionCount"), executionCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Spacer()
                        Text(L10n.text("preview.empty"))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    Color.clear.frame(height: 0).id("preview-bottom")
                    Spacer()
                }
                .padding(16)
            }
            .onReceive(NotificationCenter.default.publisher(for: .cottagePreviewScrollCommand)) { notification in
                guard let command = notification.cottagePreviewCommand else {
                    return
                }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(command == .scrollUp ? "preview-top" : "preview-bottom", anchor: .center)
                }
            }
        }
    }
}

#Preview {
    ContentView(state: CottageState())
}
