// 渲染自定义 action 的 panel、form 和结果预览界面
import AppKit
import SwiftUI

struct CustomActionPanel: View {
    // MARK: - Inputs
    @ObservedObject var state: CottageState

    // MARK: - Body

    var body: some View {
        HSplitView {
            ScrollViewReader { scrollProxy in
                if state.activeCustomAction?.definition.presentation == .form {
                    CustomActionFormView(state: state)
                } else {
                    List(selection: $state.selectedCustomResultID) {
                        if state.isCustomActionRunning {
                            Text(L10n.text("custom.result.running"))
                                .foregroundStyle(.secondary)
                        }

                        ForEach(state.customResults) { result in
                            CustomResultRow(result: result, state: state)
                        }
                    }
                    .onChange(of: state.selectedCustomResultID) { selectedResultID in
                        scroll(to: selectedResultID, with: scrollProxy)
                    }
                }
            }
            .frame(minWidth: 260, idealWidth: 360)
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .keyboardFocusBorder(state.keyboardContext == .list)

            CustomResultPreview(
                customAction: state.activeCustomAction,
                result: state.selectedCustomResult,
                state: state
            )
            .frame(minWidth: 220, idealWidth: 280)
            .keyboardFocusBorder(state.keyboardContext == .preview)
        }
    }

    private func scroll(to resultID: String?, with scrollProxy: ScrollViewProxy) {
        guard let resultID else {
            return
        }

        withAnimation(.easeOut(duration: 0.12)) {
            scrollProxy.scrollTo(resultID, anchor: .center)
        }
    }
}

private struct CustomResultRow: View {
    let result: CustomActionResult
    @ObservedObject var state: CottageState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.isError ? "exclamationmark.triangle" : "doc.text")
                .foregroundStyle(result.isError ? .red : .secondary)
            VStack(alignment: .leading) {
                Text(result.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 180, alignment: .leading)
                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 220, alignment: .leading)
                }
            }
            Spacer(minLength: 8)
            if let shortcutLabel = state.commandShortcutLabel(for: result) {
                Text(shortcutLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            resultAccessories
        }
        .contentShape(Rectangle())
        .onTapGesture {
            state.selectedCustomResultID = result.id
        }
        .onTapGesture(count: 2) {
            state.executeCustomResult(result)
        }
        .overlay(
            RightClickView {
                state.showCustomResultMenu(for: result)
            }
        )
        .popover(
            isPresented: Binding(
                get: {
                    state.shownCustomResultMenuID == result.id
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
            CustomResultActionPalette(result: result, state: state)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .tag(result.id)
        .id(result.id)
        .onAppear {
            state.markCustomResultVisible(result)
        }
        .onDisappear {
            state.markCustomResultHidden(result)
        }
    }

    private var resultAccessories: some View {
        HStack(spacing: 6) {
            ForEach(Array(result.accessories.prefix(3))) { accessory in
                HStack(spacing: 3) {
                    if let symbolName = accessory.symbolName {
                        Image(systemName: symbolName)
                    }
                    Text(accessory.text)
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(color(for: accessory.style))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
            }
        }
    }

    private func color(for style: String?) -> Color {
        switch style {
        case "success", "green":
            return .green
        case "error", "red":
            return .red
        case "warning", "orange", "yellow":
            return .orange
        case "default", "blue":
            return .blue
        case "secondary":
            return .secondary
        default:
            return .secondary
        }
    }
}

private struct CustomResultActionPalette: View {
    let result: CustomActionResult
    @ObservedObject var state: CottageState

    var body: some View {
        CottageMenu(
            title: result.title,
            entries: entries,
            onDismiss: {
                state.hideActionPalette()
            }
        )
    }

    private var entries: [CottageMenuEntry] {
        guard let customAction = state.activeCustomAction else {
            return []
        }

        return CustomResultActionMenuItems.entries(
            resultActions: customAction.definition.resultActions,
            result: result,
            state: state
        )
    }
}

private struct CustomActionFormView: View {
    @ObservedObject var state: CottageState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(state.activeCustomAction?.definition.form?.fields ?? []) { field in
                    fieldView(field)
                }
                HStack {
                    Button(L10n.text("custom.popup.run")) {
                        state.runActiveCustomActionInput()
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    if state.isCustomActionRunning {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    Spacer()
                }
                resultList
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var resultList: some View {
        List(selection: $state.selectedCustomResultID) {
            if state.isCustomActionRunning {
                Text(L10n.text("custom.result.running"))
                    .foregroundStyle(.secondary)
            }

            ForEach(state.customResults) { result in
                CustomResultRow(result: result, state: state)
            }
        }
        .frame(height: 220)
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func fieldView(_ field: CustomFormFieldDefinition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            switch field.type {
            case .text:
                TextField(field.placeholder ?? "", text: binding(for: field))
                    .textFieldStyle(.roundedBorder)
            case .password:
                SecureField(field.placeholder ?? "", text: binding(for: field))
                    .textFieldStyle(.roundedBorder)
            case .textarea:
                TextEditor(text: binding(for: field))
                    .frame(height: 90)
                    .scrollContentBackground(.hidden)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            case .checkbox:
                Toggle(field.placeholder ?? field.title, isOn: boolBinding(for: field))
            case .select:
                Picker("", selection: binding(for: field)) {
                    ForEach(field.items) { item in
                        Text(item.title).tag(item.id)
                    }
                }
                .labelsHidden()
            case .file:
                pathField(field, canChooseDirectories: false)
            case .folder:
                pathField(field, canChooseDirectories: true)
            }
        }
    }

    private func pathField(_ field: CustomFormFieldDefinition, canChooseDirectories: Bool) -> some View {
        HStack {
            TextField(field.placeholder ?? "", text: binding(for: field))
                .textFieldStyle(.roundedBorder)
            Button("…") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = !canChooseDirectories
                panel.canChooseDirectories = canChooseDirectories
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    state.updateFormValue(fieldID: field.id, value: url.path)
                }
            }
        }
    }

    private func binding(for field: CustomFormFieldDefinition) -> Binding<String> {
        Binding(
            get: {
                state.customFormValues[field.id] ?? field.defaultValue ?? ""
            },
            set: { value in
                state.updateFormValue(fieldID: field.id, value: value)
            }
        )
    }

    private func boolBinding(for field: CustomFormFieldDefinition) -> Binding<Bool> {
        Binding(
            get: {
                (state.customFormValues[field.id] ?? field.defaultValue ?? "false") == "true"
            },
            set: { value in
                state.updateFormValue(fieldID: field.id, value: value ? "true" : "false")
            }
        )
    }
}
