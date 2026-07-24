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
