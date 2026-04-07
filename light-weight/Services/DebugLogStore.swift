import Foundation
import os

enum DebugLogStore {
    private static let logger = Logger(subsystem: "com.light-weight", category: "DebugLog")
    private static let fileName = "workout-debug.log"

    static func record(_ message: String, category: String) {
        #if DEBUG
        let line = "\(Date.now.ISO8601Format()) [\(category)] \(message)"
        logger.notice("\(line, privacy: .public)")
        append(line)
        #endif
    }

    static var logURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    private static func append(_ line: String) {
        let data = Data((line + "\n").utf8)

        if FileManager.default.fileExists(atPath: logURL.path) == false {
            FileManager.default.createFile(atPath: logURL.path, contents: data)
            return
        }

        do {
            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            logger.error("Failed to write debug log: \(error.localizedDescription, privacy: .public)")
        }
    }
}
