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

extension WatchdogConfig {
    
    func saveToPreferences() {
        UserDefaults.standard.set(isEnabled, forKey: "IsEnabled")
        UserDefaults.standard.set(threshold.rawValue, forKey: "Threshold")
        UserDefaults.standard.set(action.rawValue, forKey: "Action")
    }

    static func loadFromPreferences() -> WatchdogConfig? {
        let isEnabled = UserDefaults.standard.bool(forKey: "IsEnabled")
        let rawThreshold = UserDefaults.standard.integer(forKey: "Threshold")
        let rawAction = UserDefaults.standard.integer(forKey: "Action")
        
        guard
            let threshold = Threshold(rawValue: rawThreshold),
            let action = Action(rawValue: rawAction)
        else {
            return nil
        }
        
        return WatchdogConfig(isEnabled: isEnabled, threshold: threshold, action: action)
    }
}

struct WatchdogState {
    var memoryFootprint: Int64 = 0
    var timer: Timer?
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet private var statusMenu: NSMenu!
    
    @IBOutlet private var footprintItem: NSMenuItem!
    @IBOutlet private var enabledItem: NSMenuItem!
    
    @IBOutlet private var threshold1GBItem: NSMenuItem!
    @IBOutlet private var threshold2GBItem: NSMenuItem!
    @IBOutlet private var threshold5GBItem: NSMenuItem!
    private var thresholdItems: [NSMenuItem] { return [threshold1GBItem, threshold2GBItem, threshold5GBItem] }
    
    @IBOutlet private var actionKillItem: NSMenuItem!
    @IBOutlet private var actionWarnItem: NSMenuItem!
    private var actionItems: [NSMenuItem] { return [actionKillItem, actionWarnItem] }

    private var statusItem: NSStatusItem!
    
    private var watchdogConfig: WatchdogConfig {
        didSet {
            watchdogConfig.saveToPreferences()
            updateMenus()
            evaluateState()
        }
    }
    
    private var watchdogState = WatchdogState()
    
    override init() {
        self.watchdogConfig = WatchdogConfig.loadFromPreferences() ?? .init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = statusMenu

        updateMenus()
        updateStatusIcon()
        
        NSMenu.setMenuBarVisible(false)

        DispatchQueue.main.async {
            self.sampleMemoryFootprint()
            self.restartTimer()
        }
    }

    @IBAction func killSKAgent(_ sender: Any) {
        Process.launchedProcess(launchPath: "/usr/bin/pkill", arguments: ["-9", "com.apple.dt.SKAgent"])
    }

    @IBAction func killSourceKitService(_ sender: Any) {
        watchdogState.timer?.invalidate()
        
        Process.launchedProcess(launchPath: "/usr/bin/pkill", arguments: ["-9", "SourceKitService"])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sampleMemoryFootprint()
            self.restartTimer()
        }
    }
    
    @IBAction func toggleWatchdog(_ sender: NSMenuItem) {
        watchdogConfig.isEnabled = !watchdogConfig.isEnabled
    }
    
    @IBAction func changeWatchdogThreshold(_ sender: NSMenuItem) {
        watchdogConfig.threshold = WatchdogConfig.Threshold(rawValue: sender.tag)!
    }

    @IBAction func changeWatchdogAction(_ sender: NSMenuItem) {
        watchdogConfig.action = WatchdogConfig.Action(rawValue: sender.tag)!
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if thresholdItems.contains(menuItem) || actionItems.contains(menuItem) {
            return watchdogConfig.isEnabled
        }
        
        return true
    }
    
    private func updateMenus() {
        enabledItem.state = watchdogConfig.isEnabled ? .on : .off
        
        for item in thresholdItems {
            item.state = item.tag == watchdogConfig.threshold.rawValue ? .on : .off
        }

        for item in actionItems {
            item.state = item.tag == watchdogConfig.action.rawValue ? .on : .off
        }
    }

    private func updateStatusIcon() {
        if isFootprintOverThreshold {
            statusItem.image = #imageLiteral(resourceName: "statusicon-warning")
        }
        else {
            statusItem.image = #imageLiteral(resourceName: "statusicon")
            statusItem.image?.isTemplate = true
        }
    }
    
    private func restartTimer() {
        watchdogState.timer?.invalidate()
        watchdogState.timer = Timer.scheduledTimer(timeInterval: 10,
                                                   target: self,
                                                   selector: #selector(sampleMemoryFootprint),
                                                   userInfo: nil,
                                                   repeats: true)
    }
    
    @objc private func sampleMemoryFootprint() {
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

        if let stats = sksStats {
            let segments = stats.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
            watchdogState.memoryFootprint = (String(segments.first!) as NSString).longLongValue * 1024
        }
        else {
            watchdogState.memoryFootprint = 0
        }

        let footprint = watchdogState.memoryFootprint > 0 ?
            ByteCountFormatter.string(fromByteCount: watchdogState.memoryFootprint, countStyle: .memory):
            "N/A"
        footprintItem.title = "Memory Footprint: \(footprint)"
        
        evaluateState()
    }
    
    private func evaluateState() {
        if isFootprintOverThreshold && watchdogConfig.action == .kill {
            killSourceKitService(self)
        }
        
        updateStatusIcon()
    }
    
    private var isFootprintOverThreshold: Bool {
        switch watchdogConfig.threshold {
        case .over5GB where watchdogState.memoryFootprint > 5 * 1024 * 1024 * 1024,
             .over2GB where watchdogState.memoryFootprint > 2 * 1024 * 1024 * 1024,
             .over1GB where watchdogState.memoryFootprint > 1 * 1024 * 1024 * 1024:
            return true
        default:
            return false
        }
    }

}

