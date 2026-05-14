#!/bin/bash
set -e

BINARY="$HOME/bin/finder-pdf-deselector"
PLIST="$HOME/Library/LaunchAgents/com.debruehe.finder-pdf-deselector.plist"
SOURCE="/tmp/finder-pdf-deselector.swift"

echo "Installing finder-pdf-deselector..."

# Create ~/bin if needed
mkdir -p "$HOME/bin"

# Write Swift source
cat > "$SOURCE" << 'SWIFT'
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(finderDeactivated(_:)),
            name: NSWorkspace.didDeactivateApplicationNotification,
            object: nil
        )
    }

    @objc func finderDeactivated(_ notification: Notification) {
        guard (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == "com.apple.finder" else { return }
        deselectPDFs()
    }

    func deselectPDFs() {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else { return }
        let ax = AXUIElementCreateApplication(finder.processIdentifier)
        guard let windows = axList(ax, "AXWindows") else { return }

        var deselectedAny = false
        for window in windows {
            if deselectPDFsInWindow(window) { deselectedAny = true }
        }

        if deselectedAny {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
            task.arguments = ["-r"]
            try? task.run()
        }
    }

    func deselectPDFsInWindow(_ window: AXUIElement) -> Bool {
        if let browser = findRole(window, "AXBrowser"),
           let outerScroll = axList(browser, "AXChildren")?.first,
           let columnAreas = axList(outerScroll, "AXContents") {

            for colArea in columnAreas {
                guard let contents = axList(colArea, "AXContents"),
                      contents.count == 1,
                      axStr(contents[0], "AXRole") == "AXList" else { continue }
                let list = contents[0]

                guard let selectedItems = axList(list, "AXSelectedChildren"), !selectedItems.isEmpty else { continue }

                let nonPDF = selectedItems.filter { !isTargetFile(firstName($0)) }
                if nonPDF.count < selectedItems.count {
                    let r = AXUIElementSetAttributeValue(list, "AXSelectedChildren" as CFString, nonPDF as CFArray as CFTypeRef)
                    if r == .success { return true }
                }
            }
        }

        if let splitGroup = findRole(window, "AXSplitGroup"),
           let splitChildren = axList(splitGroup, "AXChildren"),
           splitChildren.count >= 3 {
            let contentArea = splitChildren[2]
            if filterPDFsFromOutline(contentArea) { return true }
        }

        return false
    }

    func filterPDFsFromOutline(_ el: AXUIElement, depth: Int = 0) -> Bool {
        guard depth < 6 else { return false }

        for attr in ["AXSelectedRows", "AXSelectedChildren"] {
            guard let items = axList(el, attr), !items.isEmpty else { continue }
            let nonPDF = items.filter { !isTargetFile(firstName($0)) }
            if nonPDF.count < items.count {
                let r = AXUIElementSetAttributeValue(el, attr as CFString, nonPDF as CFArray as CFTypeRef)
                if r == .success { return true }
            }
        }

        if let children = axList(el, "AXChildren") {
            for child in children {
                if filterPDFsFromOutline(child, depth: depth + 1) { return true }
            }
        }
        return false
    }

    func isTargetFile(_ name: String) -> Bool {
        let lower = name.lowercased()
        let exts = [".pdf", ".mp4", ".mov", ".avi", ".mkv", ".m4v", ".wmv", ".flv",
                    ".webm", ".mpg", ".mpeg", ".m2v", ".3gp", ".3g2", ".ts", ".mts",
                    ".m2ts", ".vob", ".ogv", ".rm", ".rmvb", ".divx", ".asf"]
        return exts.contains(where: { lower.hasSuffix($0) })
    }

    func firstName(_ el: AXUIElement, depth: Int = 0) -> String {
        guard depth < 4 else { return "" }
        for attr in ["AXValue", "AXTitle", "AXDescription"] {
            if let v = axStr(el, attr), !v.isEmpty { return v }
        }
        if let children = axList(el, "AXChildren") {
            for child in children {
                let name = firstName(child, depth: depth + 1)
                if !name.isEmpty { return name }
            }
        }
        return ""
    }

    func findRole(_ el: AXUIElement, _ role: String, depth: Int = 0) -> AXUIElement? {
        guard depth < 8 else { return nil }
        if axStr(el, "AXRole") == role { return el }
        guard let children = axList(el, "AXChildren") else { return nil }
        for child in children {
            if let found = findRole(child, role, depth: depth + 1) { return found }
        }
        return nil
    }

    func axStr(_ el: AXUIElement, _ a: String) -> String? {
        var r: AnyObject?; guard AXUIElementCopyAttributeValue(el, a as CFString, &r) == .success else { return nil }; return r as? String
    }
    func axList(_ el: AXUIElement, _ a: String) -> [AXUIElement]? {
        var r: AnyObject?; guard AXUIElementCopyAttributeValue(el, a as CFString, &r) == .success else { return nil }; return r as? [AXUIElement]
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let d = AppDelegate()
app.delegate = d
app.run()
SWIFT

# Compile
echo "Compiling..."
swiftc "$SOURCE" -o "$BINARY"
rm "$SOURCE"
echo "Binary installed at $BINARY"

# Write LaunchAgent plist
cat > "$PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.debruehe.finder-pdf-deselector</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST

echo "LaunchAgent installed at $PLIST"

# Unload first in case already running
launchctl unload "$PLIST" 2>/dev/null || true

# Start it — this triggers the Accessibility permission prompt
launchctl load "$PLIST"

echo ""
echo "✓ Done. finder-pdf-deselector is running."
echo ""
echo "IMPORTANT: Grant Accessibility permission when prompted."
echo "If no prompt appears, go to:"
echo "  System Settings → Privacy & Security → Accessibility"
echo "  Add: $BINARY"
echo ""
echo "To uninstall:"
echo "  launchctl unload $PLIST"
echo "  rm $PLIST $BINARY"
