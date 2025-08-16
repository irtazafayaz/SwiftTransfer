//
//  LogLevel.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 14/08/2025.
//

import Foundation

enum LogLevel: Int { case trace = 0, debug, info, warn, error }
enum LogCat: String { case app, ui, manager, operation, urlsession }

enum LogManager {
    static var minLevel: LogLevel = .trace

    static func t(_ c: LogCat, _ m: @autoclosure () -> String) { log(.trace, c, m()) }
    static func d(_ c: LogCat, _ m: @autoclosure () -> String) { log(.debug, c, m()) }
    static func i(_ c: LogCat, _ m: @autoclosure () -> String) { log(.info,  c, m()) }
    static func w(_ c: LogCat, _ m: @autoclosure () -> String) { log(.warn,  c, m()) }
    static func e(_ c: LogCat, _ m: @autoclosure () -> String) { log(.error, c, m()) }

    private static func log(_ lvl: LogLevel, _ cat: LogCat, _ msg: @autoclosure () -> String) {        
        guard lvl.rawValue >= minLevel.rawValue else { return }
        let ts = ISO8601DateFormatter().string(from: Date())
        let thr = Thread.isMainThread ? "main" : "bg"
        NSLog("[\(ts)] [\(lvl)] [\(cat.rawValue)] [\(thr)] \(msg())")
    }
}
