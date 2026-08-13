//
//  mbvisualizerApp.swift
//  mbvisualizer
//
//  Created by Stephen Paul on 8/7/26.
//

import SwiftUI
import AppKit
import Cocoa

@main
struct mbvisualizerApp: App {
    @NSApplicationDelegateAdaptor(VisualizerBarItemDelegate.self) var appDelegate
    @AppStorage("Width") private var width: Int = 50
    @Environment(\.openWindow) var showWindow
    @State var bars: String = ""
    var body: some Scene {
        Window("Settings Window",id: "settings-window") {
            SettingsView()
        }
        .defaultLaunchBehavior(.suppressed)
        .onChange(of: width) {
            appDelegate.updateWidth(CGFloat(width))
        }
    }
}

class VisualizerBarItemDelegate: NSObject, NSApplicationDelegate {
    @Environment(\.openWindow) var showWindow
    var visStatusItem: NSStatusItem!
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        NSApp.setActivationPolicy(.prohibited)
        return false
    }
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if NSApp.windows.isEmpty {
            NSApp.setActivationPolicy(.prohibited)
        }
        
        visStatusItem = NSStatusBar.system.statusItem(withLength: 50)
        
        let hostingView = NSHostingView(rootView: VisualizerView().frame(minWidth: 25, idealWidth: 50, maxWidth: 100, minHeight: 22, idealHeight: 22, maxHeight: 22))
                hostingView.translatesAutoresizingMaskIntoConstraints = false
        if let button = visStatusItem?.button {
            button.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                hostingView.topAnchor.constraint(equalTo: button.topAnchor),
                hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
            button.toolTip = "Audio or smth Yay"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        visStatusItem?.menu = menu
    }
    func updateWidth(_ width: CGFloat) {
        visStatusItem?.length = width
    }
    @objc func openSettings() {
        NSApp.setActivationPolicy(.regular)
        showWindow(id: "settings-window")
    }
}
