// 渲染主命令面板的搜索、列表、预览和 footer
import SwiftUI

struct MainActionPanel: View {
    // MARK: - Inputs
    @ObservedObject var state: CottageState

    // MARK: - Body

    var body: some View {
        HSplitView {
            GeometryReader { proxy in
                ScrollViewReader { scrollProxy in
                    List(selection: $state.selectedActionID) {
                        if !state.favoriteFilteredActions.isEmpty {
                            favoriteSection
                        }

                        if state.favoriteFilteredActions.isEmpty {
                            actionRows(state.regularFilteredActions)
                        } else {
                            Section(L10n.text("section.allActions")) {
                                actionRows(state.regularFilteredActions)
                            }
                        }
                    }
                    .onChange(of: state.selectedActionID) { selectedActionID in
                        scroll(to: selectedActionID, with: scrollProxy)
                    }
                }
                .onAppear {
                    state.updateActionBadgeMode(width: proxy.size.width)
                }
                .onChange(of: proxy.size.width) { width in
                    state.updateActionBadgeMode(width: width)
                }
            }
            .frame(minWidth: 260, idealWidth: 360)
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .keyboardFocusBorder(state.keyboardContext == .list)

            ActionPreview(
                action: state.selectedAction,
                executionCount: state.selectedAction.map { state.executionCount(for: $0) } ?? 0
            )
            .frame(minWidth: 220, idealWidth: 280)
            .keyboardFocusBorder(state.keyboardContext == .preview)
        }
    }

    private var favoriteSection: some View {
        Section(L10n.text("section.favorites")) {
            actionRows(state.favoriteFilteredActions)
        }
    }

    private func actionRows(_ actions: [CottageAction]) -> some View {
        ForEach(actions) { action in
            ActionRow(action: action, state: state)
        }
    }

    private func scroll(to actionID: String?, with scrollProxy: ScrollViewProxy) {
        guard let actionID else {
            return
        }

        withAnimation(.easeOut(duration: 0.12)) {
            scrollProxy.scrollTo(actionID, anchor: .center)
        }
    }
}
