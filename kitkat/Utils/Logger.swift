//
//  Logger.swift
//  kitkat
//
//  Created by Richard El-Kadi on 2/23/26.
//


//
//  logger.swift
//  rte7
//
//  Created by Richard El Kadi on 6/25/24.
//

import Foundation

class Logger {
    static let shared = Logger()
    private let logFileURL: URL

    private init() {
        let fileManager = FileManager.default
        let logsDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("Logs")
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        logFileURL = logsDirectory.appendingPathComponent("rte7.log")
    }

    func log(_ message: String, level: LogLevel = .info) {
        let logMessage = "\(Date()): [\(level.rawValue)] \(message)\n"
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
        print(logFileURL)
        print(logMessage)  // Also print to console for debugging
    }
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}
