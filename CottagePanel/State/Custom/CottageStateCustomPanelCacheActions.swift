// 读写每个 action 独立的最近结果缓存
import Foundation

extension CottageState {
    func saveActiveCustomPanelCache() {
        guard let activeCustomAction else {
            return
        }

        customPanelCaches[activeCustomAction.definition.id] = CustomPanelCache(
            query: customQuery,
            results: customResults,
            selectedResultID: selectedCustomResultID,
            savedAt: Date()
        )
    }

    func restoreCustomPanelCache(for customAction: CustomAction) {
        guard let cache = customPanelCaches[customAction.definition.id] else {
            isRestoringCustomPanelCache = true
            customQuery = ""
            isRestoringCustomPanelCache = false
            customResults = []
            selectedCustomResultID = nil
            return
        }

        isRestoringCustomPanelCache = true
        customQuery = cache.query
        isRestoringCustomPanelCache = false
        customResults = cache.results
        selectedCustomResultID = cache.selectedResultID
    }
}
