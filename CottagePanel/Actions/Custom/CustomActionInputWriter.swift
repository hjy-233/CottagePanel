// 把 action 输入 payload 写入子进程 stdin。
import Foundation

enum CustomActionInputWriter {
    static func write(_ payload: CustomActionInputPayload?, to pipe: Pipe) {
        defer {
            try? pipe.fileHandleForWriting.close()
        }

        guard let payload,
              let data = try? JSONEncoder().encode(payload) else {
            return
        }

        pipe.fileHandleForWriting.write(data)
    }
}
