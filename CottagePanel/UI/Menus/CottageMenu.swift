// 渲染可复用的 Cottage 弹出菜单和子菜单
import SwiftUI

// MARK: - Menu Models

struct CottageMenuItem: Identifiable {
    let id: String
    let title: String
    let shortcut: String?
    let symbolName: String
    let isDestructive: Bool
    let children: [CottageMenuItem]
    let action: () -> Void

    init(
        id: String,
        title: String,
        shortcut: String? = nil,
        symbolName: String,
        isDestructive: Bool = false,
        children: [CottageMenuItem] = [],
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.shortcut = shortcut
        self.symbolName = symbolName
        self.isDestructive = isDestructive
        self.children = children
        self.action = action
    }
}

enum CottageMenuEntry: Identifiable {
    case item(CottageMenuItem)
    case divider(String)

    var id: String {
        switch self {
        case .item(let item):
            item.id
        case .divider(let id):
            id
        }
    }
}

// MARK: - Menu View

struct CottageMenu: View {
    let title: String?
    let entries: [CottageMenuEntry]
    let onDismiss: (() -> Void)?
    @State private var submenuStack: [CottageSubmenuState] = []
    @State private var selectedItemID: String?

    init(title: String?, items: [CottageMenuItem]) {
        self.title = title
        entries = items.map(CottageMenuEntry.item)
        onDismiss = nil
    }

    init(title: String?, entries: [CottageMenuEntry], onDismiss: (() -> Void)? = nil) {
        self.title = title
        self.entries = entries
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if !submenuStack.isEmpty {
                    Button {
                        _ = submenuStack.popLast()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                }
                if let visibleTitle {
                    Text(visibleTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 2)

            List(selection: $selectedItemID) {
                ForEach(visibleEntries) { entry in
                    switch entry {
                    case .item(let item):
                        menuButton(item)
                            .tag(item.id)
                    case .divider:
                        Divider()
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .frame(height: menuHeight)
        }
        .padding(12)
        .frame(width: 300, height: totalHeight)
        .onAppear {
            selectFirstItemIfNeeded()
        }
        .onChange(of: visibleEntries.map(\.id)) { _ in
            selectFirstItemIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cottageMenuKeyboardCommand)) { notification in
            guard let command = notification.cottageMenuCommand else {
                return
            }
            handle(command)
        }
    }

    private var visibleTitle: String? {
        submenuStack.last?.title ?? title
    }

    private var visibleEntries: [CottageMenuEntry] {
        submenuStack.last?.entries ?? entries
    }

    private var visibleItems: [CottageMenuItem] {
        visibleEntries.compactMap { entry in
            if case .item(let item) = entry {
                return item
            }
            return nil
        }
    }

    private var menuHeight: CGFloat {
        let measuredHeight = visibleEntries.reduce(CGFloat(0)) { partialHeight, entry in
            partialHeight + defaultHeight(for: entry)
        }
        return min(max(measuredHeight, 1), 420)
    }

    private var totalHeight: CGFloat {
        let titleHeight = visibleTitle == nil ? CGFloat(0) : 30
        return min(titleHeight + menuHeight + 34, 480)
    }

    private func defaultHeight(for entry: CottageMenuEntry) -> CGFloat {
        switch entry {
        case .item:
            return 34
        case .divider:
            return 12
        }
    }

    private func menuButton(_ item: CottageMenuItem) -> some View {
        Button {
            activate(item)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbolName)
                    .frame(width: 18)
                Text(item.title)
                Spacer()
                if let shortcut = item.shortcut {
                    Button(shortcut) {
                        item.action()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                if !item.children.isEmpty {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(item.isDestructive ? .red : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering {
                selectedItemID = item.id
            }
        }
        .onTapGesture(count: 2) {
            item.action()
        }
    }

    private func handle(_ command: CottageMenuKeyboardCommand) {
        switch command {
        case .moveUp:
            moveSelection(offset: -1)
        case .moveDown:
            moveSelection(offset: 1)
        case .enter:
            selectedItem.map(activate)
        case .moveLeft:
            if !submenuStack.isEmpty {
                _ = submenuStack.popLast()
                selectFirstItemIfNeeded()
            }
        case .moveRight:
            guard let selectedItem, !selectedItem.children.isEmpty else {
                return
            }
            openSubmenu(selectedItem)
        case .backspace:
            if !submenuStack.isEmpty {
                _ = submenuStack.popLast()
                selectFirstItemIfNeeded()
            }
        case .escape:
            onDismiss?()
        }
    }

    private var selectedItem: CottageMenuItem? {
        guard let selectedItemID else {
            return visibleItems.first
        }

        return visibleItems.first { $0.id == selectedItemID }
    }

    private func moveSelection(offset: Int) {
        guard !visibleItems.isEmpty else {
            selectedItemID = nil
            return
        }

        let currentIndex = visibleItems.firstIndex { $0.id == selectedItemID } ?? 0
        let nextIndex = (currentIndex + offset + visibleItems.count) % visibleItems.count
        selectedItemID = visibleItems[nextIndex].id
    }

    private func selectFirstItemIfNeeded() {
        guard let firstItem = visibleItems.first else {
            selectedItemID = nil
            return
        }

        if selectedItemID == nil || visibleItems.contains(where: { $0.id == selectedItemID }) == false {
            selectedItemID = firstItem.id
        }
    }

    private func activate(_ item: CottageMenuItem) {
        if item.children.isEmpty {
            item.action()
        } else {
            openSubmenu(item)
        }
    }

    private func openSubmenu(_ item: CottageMenuItem) {
        submenuStack.append(
            CottageSubmenuState(
                title: item.title,
                entries: item.children.map(CottageMenuEntry.item)
            )
        )
        selectedItemID = item.children.first?.id
    }
}

private struct CottageSubmenuState {
    let title: String
    let entries: [CottageMenuEntry]
}
