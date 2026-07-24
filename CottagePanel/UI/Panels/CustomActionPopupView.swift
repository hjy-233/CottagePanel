import SwiftUI

struct CustomActionPopupView: View {
    @ObservedObject var state: CottageState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(state.popupCustomAction?.definition.title ?? L10n.text("custom.popup.title"))
                .font(.headline)

            CustomSearchField(
                text: $state.popupInput,
                placeholder: L10n.text("custom.popup.placeholder"),
                focusTrigger: state.searchFocusTrigger
            ) {
                state.runPopupAction()
            }
            .frame(height: 44)

            controls
            output
        }
        .padding(20)
        .frame(width: 420, height: 260)
        .onAppear {
            state.focusSearch()
        }
        .onExitCommand {
            state.closeCustomPopup()
        }
    }

    private var controls: some View {
        HStack {
            Button(L10n.text("custom.popup.run")) {
                state.runPopupAction()
            }
            .keyboardShortcut(.return, modifiers: [])
            Button(L10n.text("custom.popup.copy")) {
                state.copyPopupOutput()
            }
            .disabled(state.popupOutput.isEmpty)
            Spacer()
            if state.isPopupRunning {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }

    private var output: some View {
        ScrollView {
            Text(state.popupOutput.isEmpty ? L10n.text("custom.popup.empty") : state.popupOutput)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .foregroundStyle(state.popupOutput.isEmpty ? .secondary : .primary)
        }
        .frame(minHeight: 120)
    }
}
