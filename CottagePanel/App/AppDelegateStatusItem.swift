import AppKit

extension AppDelegate {
    func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = statusBarIcon()
        item.button?.imagePosition = .imageOnly
        statusItem = item
        refreshStatusMenu()
    }

    func refreshStatusMenu() {
        guard let statusItem else {
            return
        }

        let menu = NSMenu()
        addBaseStatusItems(to: menu)
        addMenuBarActions(to: menu)
        addQuitStatusItem(to: menu)
        menu.items.forEach { item in
            item.target = self
        }
        statusItem.menu = menu
    }

    private func addBaseStatusItems(to menu: NSMenu) {
        menu.addItem(statusItem(title: L10n.text("footer.appName"), action: #selector(showPanelFromStatusItem)))
        menu.addItem(
            statusItem(title: L10n.text("appMenu.openSettings"), action: #selector(showSettingsFromStatusItem))
        )
        menu.addItem(
            statusItem(title: L10n.text("settings.reloadActions"), action: #selector(reloadActionsFromStatusItem))
        )
        menu.addItem(NSMenuItem.separator())
    }

    private func addMenuBarActions(to menu: NSMenu) {
        state.actions
            .compactMap(\.customAction)
            .filter { $0.definition.menuBar?.enabled == true }
            .sorted { lhs, rhs in
                lhs.definition.menuBar?.order ?? 0 < rhs.definition.menuBar?.order ?? 0
            }
            .forEach { customAction in
                addMenuBarAction(customAction, to: menu)
            }
        if menu.items.last?.isSeparatorItem == false {
            menu.addItem(NSMenuItem.separator())
        }
    }

    private func addMenuBarAction(_ customAction: CustomAction, to menu: NSMenu) {
        let item = statusItem(
            title: customAction.definition.menuBar?.title ?? customAction.definition.title,
            action: #selector(runMenuBarAction(_:))
        )
        if let symbolName = customAction.definition.menuBar?.symbolName ?? customAction.definition.symbolName {
            item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        }
        item.representedObject = customAction
        menu.addItem(item)
    }

    private func addQuitStatusItem(to menu: NSMenu) {
        menu.addItem(statusItem(title: L10n.text("appMenu.quitCottage"), action: #selector(quitFromStatusItem)))
    }

    private func statusItem(title: String, action: Selector) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: "")
    }

    private func statusBarIcon() -> NSImage? {
        CottageAppIcon.image(size: NSSize(width: 18, height: 18))
    }

    @objc private func showPanelFromStatusItem() {
        showPanel()
    }

    @objc private func showSettingsFromStatusItem() {
        showPanel()
        state.openSettings()
    }

    @objc private func reloadActionsFromStatusItem() {
        state.reloadActionsFromUserAction()
    }

    @objc private func runMenuBarAction(_ item: NSMenuItem) {
        guard let customAction = item.representedObject as? CustomAction else {
            return
        }

        showPanel()
        state.runCustomAction(customAction)
    }

    @objc private func quitFromStatusItem() {
        NSApp.terminate(nil)
    }
}
