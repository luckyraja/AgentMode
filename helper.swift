import AppKit
import CoreGraphics

// agentmode-helper: the bits of agent-mode that shell can't do cleanly.
//   display get                  -> "1920x1080 hidpi"
//   display list                 -> every mode the main display offers
//   display set 1920x1080 hidpi  -> switch the main display (permanent until changed)
//   running <bundle-id>...       -> prints the ids that are running
//   quit <bundle-id>...          -> politely quits each, prints the ids that quit

let display = CGMainDisplayID()

func describe(_ m: CGDisplayMode) -> String {
    "\(m.width)x\(m.height)" + (m.pixelWidth > m.width ? " hidpi" : "")
}

func allModes() -> [CGDisplayMode] {
    let opts = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
    return (CGDisplayCopyAllDisplayModes(display, opts) as? [CGDisplayMode] ?? [])
        .filter { $0.isUsableForDesktopGUI() }
}

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

func running(_ id: String) -> [NSRunningApplication] {
    NSRunningApplication.runningApplications(withBundleIdentifier: id)
}

let args = Array(CommandLine.arguments.dropFirst())

switch (args.first, args.dropFirst().first) {
case ("display", "get"):
    guard let m = CGDisplayCopyDisplayMode(display) else { fail("no display mode") }
    print(describe(m))

case ("display", "list"):
    var seen = Set<String>()
    for m in allModes().sorted(by: { $0.width > $1.width }) where seen.insert(describe(m)).inserted {
        print(describe(m))
    }

case ("display", "set"):
    guard args.count >= 3 else { fail("usage: display set WxH [hidpi]") }
    let want = args[2] + (args.count > 3 && args[3] == "hidpi" ? " hidpi" : "")
    // Prefer the current refresh rate, then the highest one.
    let current = CGDisplayCopyDisplayMode(display)?.refreshRate ?? 0
    let matches = allModes().filter { describe($0) == want }
        .sorted { ($0.refreshRate == current ? 1 : 0, $0.refreshRate) > ($1.refreshRate == current ? 1 : 0, $1.refreshRate) }
    guard let mode = matches.first else { fail("no mode \(want); see `display list`") }
    var config: CGDisplayConfigRef?
    CGBeginDisplayConfiguration(&config)
    CGConfigureDisplayWithDisplayMode(config, display, mode, nil)
    guard CGCompleteDisplayConfiguration(config, .permanently) == .success else { fail("couldn't set \(want)") }
    print(describe(mode))

case ("running", _):
    for id in args.dropFirst() where !running(id).isEmpty { print(id) }

case ("quit", _):
    let ids = args.dropFirst().filter { !running($0).isEmpty }
    for id in ids { running(id).forEach { $0.terminate() } }
    // Give apps a few seconds to close; one showing a save dialog stays open.
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline, ids.contains(where: { !running($0).isEmpty }) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    }
    for id in ids where running(id).isEmpty { print(id) }

default:
    fail("usage: agentmode-helper display get|list|set WxH [hidpi] | running ID... | quit ID...")
}
