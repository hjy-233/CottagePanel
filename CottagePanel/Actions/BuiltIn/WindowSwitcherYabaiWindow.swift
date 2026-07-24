struct YabaiWindow: Decodable {
    let id: Int
    let pid: Int32
    let app: String
    let title: String
    let space: Int
    let role: String
    let subrole: String
    let level: Int
    let opacity: Double

    enum CodingKeys: String, CodingKey {
        case id
        case pid
        case app
        case title
        case space
        case role
        case subrole
        case level
        case opacity
    }

    var windowSwitcherItem: WindowSwitcherItem? {
        guard role == "AXWindow",
              subrole == "AXStandardWindow",
              level == 0,
              opacity > 0,
              !title.trimmedSearchText.isEmpty else {
            return nil
        }

        return WindowSwitcherItem(
            windowID: id,
            pid: pid,
            title: title,
            appName: app,
            space: space,
            source: .yabai
        )
    }
}
