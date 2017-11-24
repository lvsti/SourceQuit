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

    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        statusItem.image = NSImage(named: NSImage.Name(rawValue: "statusicon"))
        statusItem.image?.isTemplate = true
        
        NSMenu.setMenuBarVisible(false)

        let menu = NSMenu(title: statusItem.title!)
        let menuItems = buildMenuItems()
        
        for item in menuItems {
            menu.addItem(item)
        }
        
        statusItem.menu = menu
    }
    
    private func buildMenuItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        
        items.append(NSMenuItem(title: "Kill com.apple.dt.SKAgent",
                                action: #selector(killSKAgent(_:)),
                                keyEquivalent: ""))
        items.append(NSMenuItem(title: "Kill SourceKitService",
                                action: #selector(killSourceKitService(_:)),
                                keyEquivalent: ""))
        items.append(.separator())
        items.append(NSMenuItem(title: "Quit SourceQuit",
                                action: #selector(quit(_:)),
                                keyEquivalent: ""))
        
        return items
    }
    
    @objc private func killSKAgent(_ sender: Any) {
        Process.launchedProcess(launchPath: "/usr/bin/pkill", arguments: ["-9", "com.apple.dt.SKAgent"])
    }

    @objc private func killSourceKitService(_ sender: Any) {
        Process.launchedProcess(launchPath: "/usr/bin/pkill", arguments: ["-9", "SourceKitService"])
    }

    @objc private func quit(_ sender: Any) {
        NSApplication.shared.terminate(nil)
    }

}

