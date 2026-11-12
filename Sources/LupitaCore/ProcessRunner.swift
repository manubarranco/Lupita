import Foundation

/// Runs one executable and returns its stdout when it exits 0 (nil otherwise); stderr is dropped.
/// A command still running after `timeout` seconds is terminated, so a lookup never hangs on it.
enum ProcessRunner {
    static func output(_ executable: String, _ args: [String], environment: [String: String]? = nil,
                       timeout: TimeInterval) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        if let environment { process.environment = environment }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { if process.isRunning { process.terminate() } }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
    }
}
