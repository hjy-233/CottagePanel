// 管理 popup action 的打开、运行和关闭
import AppKit
import Foundation

extension CottageState {
    func runPopupAction() {
        guard let popupCustomAction else {
            return
        }

        guard popupCustomAction.definition.input.allowsEmptyQuery || !popupInput.trimmedSearchText.isEmpty else {
            showStatus(L10n.text("status.noResult"))
            return
        }

        popupOutput = ""
        isPopupRunning = true
        showStatus(L10n.text("status.running"))
        stopCustomProcess()
        let processID = UUID()
        activeCustomProcessID = processID
        customProcess = CustomActionRunner.runProcess(
            CustomActionProcessRequest(
                customAction: popupCustomAction,
                query: popupInput,
                inputPayload: popupInputPayload(for: popupCustomAction),
                timeoutInterval: 15,
                processID: processID
            ),
            handlers: popupHandlers(processID: processID, customAction: popupCustomAction)
        )
        if customProcess == nil {
            activeCustomProcessID = nil
            popupOutput = L10n.text("custom.result.unsupported")
            isPopupRunning = false
            showStatus(L10n.text("status.actionFailed"))
        }
    }

    func copyPopupOutput() {
        guard !popupOutput.isEmpty else {
            showStatus(L10n.text("status.noResult"))
            return
        }

        copyText(popupOutput)
    }

    func copySelectedCustomResult() {
        guard let selectedCustomResult else {
            showStatus(L10n.text("status.noResult"))
            return
        }

        if let imagePath = selectedCustomResult.previewImagePath ?? selectedCustomResult.path,
           copyImage(at: imagePath) {
            showStatus(L10n.text("status.copied"))
            return
        }

        let text = selectedCustomResult.text.isEmpty
            ? selectedCustomResult.title
            : selectedCustomResult.text
        copyText(text)
    }

    func closeCustomPopup() {
        guard showsCustomPopup else {
            return
        }

        stopCustomProcess()
        showsCustomPopup = false
        popupCustomAction = nil
        popupInput = ""
        popupOutput = ""
        isPopupRunning = false
        focusSearch()
    }

    func showCustomPopup(_ customAction: CustomAction) {
        stopCustomProcess()
        popupCustomAction = customAction
        popupInput = ""
        popupOutput = ""
        isPopupRunning = false
        showsActionPalette = false
        showsCustomPopup = true
    }

    private func appendPopupOutput(_ text: String) {
        if popupOutput.isEmpty {
            popupOutput = text
        } else {
            popupOutput.append("\n\(text)")
        }
    }

    private func popupInputPayload(for customAction: CustomAction) -> CustomActionInputPayload {
        CustomActionInputPayload(
            apiVersion: customAction.definition.apiVersion,
            query: popupInput,
            form: [:],
            accessory: [:],
            result: nil,
            navigation: nil
        )
    }

    private func popupHandlers(
        processID: UUID,
        customAction: CustomAction
    ) -> CustomActionProcessHandlers {
        CustomActionProcessHandlers(
            onLine: { [weak self] line in
                guard let self, self.activeCustomProcessID == processID else {
                    return
                }

                self.appendPopupOutput(line)
            },
            onError: { [weak self] errorText in
                guard let self, self.activeCustomProcessID == processID else {
                    return
                }

                self.appendPopupOutput(errorText)
            },
            onCompletion: { [weak self] status in
                self?.finishPopupRun(processID: processID, status: status, customAction: customAction)
            }
        )
    }

    private func finishPopupRun(
        processID: UUID,
        status: Int32,
        customAction: CustomAction
    ) {
        guard activeCustomProcessID == processID else {
            return
        }

        activeCustomProcessID = nil
        isPopupRunning = false
        if status == 0 {
            showStatus(L10n.text("status.done"))
            applyPostRun(customAction.definition.postRun)
        } else {
            showStatus(L10n.text("status.actionFailed"))
        }
    }
}

private func copyImage(at path: String) -> Bool {
    let expandedPath = NSString(string: path).expandingTildeInPath
    guard let image = NSImage(contentsOfFile: expandedPath) else {
        return false
    }

    NSPasteboard.general.clearContents()
    return NSPasteboard.general.writeObjects([image])
}
