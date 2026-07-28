// 提供打开路径、提示缺失目录等搜索辅助动作
import AppKit

func openHomePath(_ path: String) {
    let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(path)
    NSWorkspace.shared.open(url)
}

func openURL(_ string: String) {
    guard let url = URL(string: string) else {
        return
    }

    NSWorkspace.shared.open(url)
}

func normalizedSearchText(_ text: String) -> String {
    text
        .lowercased()
        .filter { $0.isLetter || $0.isNumber }
}

func searchInitials(from text: String) -> String {
    var initials = ""
    var isInsideWord = false

    for character in text {
        if character.isHan {
            initials.append(transliteratedInitial(from: character))
            isInsideWord = false
        } else if character.isLetter || character.isNumber {
            if !isInsideWord {
                initials.append(String(character).lowercased())
                isInsideWord = true
            }
        } else {
            isInsideWord = false
        }
    }

    return initials
}

extension CottageState {
    func openConfigDirectory() {
        ensureConfigDirectory()
        NSWorkspace.shared.open(configDirectory)
    }
}

private func transliteratedInitial(from character: Character) -> String {
    let mutableText = NSMutableString(string: String(character))
    CFStringTransform(mutableText, nil, kCFStringTransformToLatin, false)
    CFStringTransform(mutableText, nil, kCFStringTransformStripCombiningMarks, false)

    return (mutableText as String)
        .first(where: { $0.isLetter || $0.isNumber })
        .map { String($0).lowercased() } ?? ""
}

private extension Character {
    var isHan: Bool {
        unicodeScalars.contains { value in
            (0x4E00...0x9FFF).contains(value.value)
                || (0x3400...0x4DBF).contains(value.value)
                || (0x20000...0x2A6DF).contains(value.value)
        }
    }
}
