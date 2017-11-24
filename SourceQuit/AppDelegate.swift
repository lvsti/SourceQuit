//
//  AppDelegate.swift
//  SourceQuit
//
//  Created by Tamas Lustyik on 2017. 11. 23..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Cocoa

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
    }
    
    @IBAction func changeWatchdogThreshold(_ sender: NSMenuItem) {
    }

    @IBAction func changeWatchdogAction(_ sender: NSMenuItem) {
    }
    

}

