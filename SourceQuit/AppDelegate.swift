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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        statusItem.image = NSImage(named: NSImage.Name(rawValue: "statusicon"))
        statusItem.image?.isTemplate = true
        
        NSMenu.setMenuBarVisible(false)

        statusItem.menu = statusMenu
    }

    @IBAction func killSKAgent(_ sender: Any) {
        Process.launchedProcess(launchPath: "/usr/bin/pkill", arguments: ["-9", "com.apple.dt.SKAgent"])
    }

    @IBAction func killSourceKitService(_ sender: Any) {
        Process.launchedProcess(launchPath: "/usr/bin/pkill", arguments: ["-9", "SourceKitService"])
    }
    
    @IBAction func toggleWatchdog(_ sender: NSMenuItem) {
        watchdogConfig.isEnabled = !watchdogConfig.isEnabled
        sender.state = watchdogConfig.isEnabled ? .on : .off

    }
    
    @IBAction func changeWatchdogThreshold(_ sender: NSMenuItem) {
        watchdogConfig.threshold = WatchdogConfig.Threshold(rawValue: sender.tag)!
        sender.state = .on
        
        for item in thresholdItems where item != sender {
            item.state = .off
        }

    }

    @IBAction func changeWatchdogAction(_ sender: NSMenuItem) {
        watchdogConfig.action = WatchdogConfig.Action(rawValue: sender.tag)!
        sender.state = .on
        
        for item in actionItems where item != sender {
            item.state = .off
        }
        
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if thresholdItems.contains(menuItem) || actionItems.contains(menuItem) {
            return watchdogConfig.isEnabled
        }

        return true
    }
    }
    

}

