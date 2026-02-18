import Cocoa

// Entry point: start NSApplication with our delegate.
// We use main.swift (not @main) so that top-level code can set the delegate
// before NSApplication.run() takes over the thread.
//
// NSApplication is required (not just a bare Foundation tool) because
// UNUserNotificationCenter requires a running .app bundle with a proper
// bundle identifier, and the delegate handles notification click callbacks
// when the OS relaunches the app.

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
