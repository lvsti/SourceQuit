//
//  AppDelegate.swift
//  SourceQuit
//
//  Created by Tamas Lustyik on 2017. 11. 23..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Cocoa


struct WatchdogConfig {
    enum Threshold: Int {
        case over1GB = 0x100
        case over2GB = 0x101
        case over5GB = 0x102
    }
    
    enum Action: Int {
        case kill = 0x200
        case warn = 0x201
    }

    var isEnabled: Bool = false
    var threshold: Threshold = .over1GB
    var action: Action = .kill
}

struct WatchdogState {
    var isShowingWarning: Bool = false
    var timer: Timer?
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet private var statusMenu: NSMenu!
    
    @IBOutlet private var threshold1GBItem: NSMenuItem!
    @IBOutlet private var threshold2GBItem: NSMenuItem!
    @IBOutlet private var threshold5GBItem: NSMenuItem!
    private var thresholdItems: [NSMenuItem] { return [threshold1GBItem, threshold2GBItem, threshold5GBItem] }
    
    @IBOutlet private var actionKillItem: NSMenuItem!
    @IBOutlet private var actionWarnItem: NSMenuItem!
    private var actionItems: [NSMenuItem] { return [actionKillItem, actionWarnItem] }

    private var statusItem: NSStatusItem!
    
    private var watchdogConfig = WatchdogConfig()
    private var watchdogState = WatchdogState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        updateStatusIcon()
        
        NSMenu.setMenuBarVisible(false)

        statusItem.menu = statusMenu
    }

    @IBAction func killSKAgent(_ sender: Any) {
        Process.launchedProcess(launchPath: "/usr/bin/pkill", arguments: ["-9", "com.apple.dt.SKAgent"])
    }

    @IBAction func killSourceKitService(_ sender: Any) {
        Process.launchedProcess(launchPath: "/usr/bin/pkill", arguments: ["-9", "SourceKitService"])
        watchdogState.isShowingWarning = false
        updateStatusIcon()
    }
    
    @IBAction func toggleWatchdog(_ sender: NSMenuItem) {
        watchdogConfig.isEnabled = !watchdogConfig.isEnabled
        sender.state = watchdogConfig.isEnabled ? .on : .off

        updateWatchdog()
    }
    
    @IBAction func changeWatchdogThreshold(_ sender: NSMenuItem) {
        watchdogConfig.threshold = WatchdogConfig.Threshold(rawValue: sender.tag)!
        sender.state = .on
        
        for item in thresholdItems where item != sender {
            item.state = .off
        }

        updateWatchdog()
    }

    @IBAction func changeWatchdogAction(_ sender: NSMenuItem) {
        watchdogConfig.action = WatchdogConfig.Action(rawValue: sender.tag)!
        sender.state = .on
        
        for item in actionItems where item != sender {
            item.state = .off
        }
        
        updateWatchdog()
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if thresholdItems.contains(menuItem) || actionItems.contains(menuItem) {
            return watchdogConfig.isEnabled
        }

        return true
    }

    private func updateStatusIcon() {
        if watchdogState.isShowingWarning {
            statusItem.image = #imageLiteral(resourceName: "statusicon-warning")
        }
        else {
            statusItem.image = #imageLiteral(resourceName: "statusicon")
            statusItem.image?.isTemplate = true
        }
    }
    
    private func updateWatchdog() {
        watchdogState.timer?.invalidate()
        watchdogState.timer = Timer.scheduledTimer(timeInterval: 10,
                                                   target: self,
                                                   selector: #selector(watchdogTimerDidFire),
                                                   userInfo: nil,
                                                   repeats: true)
    }
    
    @objc private func watchdogTimerDidFire() {
        let ps = Process()
        ps.launchPath = "/bin/ps"
        ps.arguments = ["x", "-o", "rss,comm"]

        let pipe = Pipe()
        ps.standardOutput = pipe
        
        ps.launch()
        ps.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: String.Encoding.utf8) else {
            return
        }

        var sksStats: String?
        output.enumerateLines { line, stop in
            if line.hasSuffix("SourceKitService.xpc/Contents/MacOS/SourceKitService") {
                sksStats = line
                stop = true
            }
        }

        guard let stats = sksStats else { return }
        let segments = stats.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let memoryFootprint = (String(segments.first!) as NSString).longLongValue
        
        NSLog("SourceKitService real memory footprint: \(memoryFootprint)")
        
        switch watchdogConfig.threshold {
        case .over5GB where memoryFootprint > 5 * 1024 * 1024 * 1024,
             .over2GB where memoryFootprint > 2 * 1024 * 1024 * 1024,
             .over1GB where memoryFootprint > 1 * 1024 * 1024 * 1024:
            switch watchdogConfig.action {
            case .warn:
                if !watchdogState.isShowingWarning {
                    watchdogState.isShowingWarning = true
                    updateStatusIcon()
                }
            case .kill:
                killSourceKitService(self)
            }
        default:
            if watchdogState.isShowingWarning {
                watchdogState.isShowingWarning = false
                updateStatusIcon()
            }
            break
        }

    }
}

