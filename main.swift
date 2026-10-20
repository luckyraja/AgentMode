import AppKit
import ServiceManagement

// Menu bar front end for ~/.local/bin/agent-mode.
// Left-click toggles agent/human mode; right-click shows a menu.

enum AgentMode {
    static let path = NSHomeDirectory() + "/.local/bin/agent-mode"

    @discardableResult
    static func run(_ arg: String) -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = [arg]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch { return (-1, "\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static var isAgent: Bool { run("status").output == "agent" }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var busy = false
    private var lastMessage = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? SMAppService.mainApp.register()  // start at login
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refresh()
        // OpenClaw or a terminal may flip the mode behind our back.
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        guard !busy, let button = item.button else { return }
        let agent = AgentMode.isAgent
        button.title = agent ? "🤖" : "🧑"
        button.toolTip = (agent ? "Agent mode — click to switch to human mode" : "Human mode — click to switch to agent mode")
            + (lastMessage.isEmpty ? "" : "\n" + lastMessage)
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu() } else { toggle() }
    }

    private func toggle() {
        guard !busy else { return }
        busy = true
        item.button?.title = "⏳"
        DispatchQueue.global().async {
            let (status, out) = AgentMode.run("toggle")
            DispatchQueue.main.async {
                self.busy = false
                self.lastMessage = out
                if status != 0 { self.alert("agent-mode failed", out) }
                self.refresh()
            }
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let agent = AgentMode.isAgent
        menu.addItem(disabled(agent ? "Agent mode" : "Human mode"))
        if !lastMessage.isEmpty {
            lastMessage.split(separator: "\n").forEach { menu.addItem(disabled(String($0))) }
        }
        menu.addItem(.separator())
        let toggle = NSMenuItem(title: agent ? "Switch to Human Mode" : "Switch to Agent Mode",
                                action: #selector(toggleFromMenu), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit AgentMode", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil  // so the next left-click toggles instead of opening the menu
    }

    @objc private func toggleFromMenu() { toggle() }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
