import SwiftUI
import Combine
import ScreenCaptureKit

struct Click: Codable { var x: Double; var y: Double; var delay: Double }
struct Job: Codable, Identifiable { var id = UUID(); var clicks: [Click]; var fire: Date }
struct Shot: Codable, Identifiable { var id = UUID(); var file: String }
struct Preset: Codable, Identifiable { var id = UUID(); var name: String; var clicks: [Click] }
private struct Saved: Codable { var jobs: [Job]; var shots: [Shot]; var presets: [Preset]? }

final class Store: ObservableObject {
    static let dir = URL.applicationSupportDirectory.appending(path: "PointerDrop")
    private static let file = dir.appending(path: "state.json")

    @Published var jobs: [Job] = [] { didSet { save(); updateAwake() } }
    @Published var shots: [Shot] = [] { didSet { save() } }
    @Published var presets: [Preset] = [] { didSet { save() } }
    @Published var draft: [Click] = []
    @Published var draftSaved = false
    @Published var blockClicks = false
    @Published var recording = false
    @Published var running = false
    @Published var done = false

    private var tap: CFMachPort?
    private var last: Date?
    private var swallowing = false
    private var awake: NSObjectProtocol?

    init() {
        try? FileManager.default.createDirectory(at: Self.dir, withIntermediateDirectories: true)
        if let d = try? Data(contentsOf: Self.file), let s = try? JSONDecoder().decode(Saved.self, from: d) {
            // ponytail: jobs overdue by more than a minute are dropped, never fire stale clicks after relaunch
            jobs = s.jobs.filter { $0.fire > .now - 60 }
            shots = s.shots
            presets = s.presets ?? []
            done = !shots.isEmpty
        }
        updateAwake()
        // ponytail: 1s poll survives system sleep; swap for per-job timers if sub-second accuracy matters
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func save() {
        try? JSONEncoder().encode(Saved(jobs: jobs, shots: shots, presets: presets)).write(to: Self.file)
    }

    private func updateAwake() {
        if jobs.isEmpty, let a = awake { ProcessInfo.processInfo.endActivity(a); awake = nil }
        else if !jobs.isEmpty, awake == nil {
            awake = ProcessInfo.processInfo.beginActivity(
                options: [.idleSystemSleepDisabled, .idleDisplaySleepDisabled, .userInitiated],
                reason: "Scheduled clicks")
        }
    }

    // MARK: Record

    func startRecording() {
        guard AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) else { return }
        draft = []; draftSaved = false; last = nil
        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue | 1 << CGEventType.leftMouseUp.rawValue)
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: mask, callback: tapCallback,
                                        userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        tap = t; recording = true
    }

    func stopRecording() {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false); CFMachPortInvalidate(t) }
        tap = nil; recording = false
    }

    // Returns true when the event must be swallowed: Block clicks on and Option held.
    fileprivate func handle(_ type: CGEventType, _ p: CGPoint, _ flags: CGEventFlags) -> Bool {
        if type == .leftMouseUp { defer { swallowing = false }; return swallowing }
        guard !isOurs(p) else { return false }
        let now = Date()
        draft.append(Click(x: p.x, y: p.y, delay: last.map { now.timeIntervalSince($0) } ?? 0))
        last = now
        swallowing = blockClicks && flags.contains(.maskAlternate)
        return swallowing
    }

    // Skips the menu bar band and our own panel so Stop is not recorded.
    private func isOurs(_ p: CGPoint) -> Bool {
        if p.y >= 0 && p.y < 40 { return true }
        let h = NSScreen.screens[0].frame.height
        return NSApp.windows.contains {
            $0.isVisible && CGRect(x: $0.frame.minX, y: h - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height).contains(p)
        }
    }

    // MARK: Schedule + run

    func schedule(at date: Date) {
        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
        jobs.append(Job(clicks: draft, fire: date))
        jobs.sort { $0.fire < $1.fire }
        draft = []; draftSaved = false
    }

    func savePreset() {
        let when = Date.now.formatted(.dateTime.month().day().hour().minute())
        presets.insert(Preset(name: "\(draft.count) clicks · \(when)", clicks: draft), at: 0)
        draftSaved = true
    }

    func load(_ p: Preset) { draft = p.clicks; draftSaved = true }

    private func tick() {
        guard !running, let j = jobs.first(where: { $0.fire <= .now }) else { return }
        Task { await run(j) }
    }

    private func run(_ job: Job) async {
        running = true
        for c in job.clicks {
            try? await Task.sleep(for: .seconds(c.delay))
            let p = CGPoint(x: c.x, y: c.y)
            CGWarpMouseCursorPosition(p)
            try? await Task.sleep(for: .milliseconds(150))
            await shoot(p)
            for t in [CGEventType.leftMouseDown, .leftMouseUp] {
                CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        jobs.removeAll { $0.id == job.id }
        running = false
        done = true
    }

    // 20% x 20% of the display, centered on the cursor; shifted inward at screen edges.
    private func shoot(_ p: CGPoint) async {
        guard let content = try? await SCShareableContent.current,
              let d = content.displays.first(where: { CGDisplayBounds($0.displayID).contains(p) }) else { return }
        let b = CGDisplayBounds(d.displayID)
        let w = b.width * 0.2, h = b.height * 0.2
        let cfg = SCStreamConfiguration()
        cfg.sourceRect = CGRect(x: min(max(p.x - w / 2, b.minX), b.maxX - w) - b.minX,
                                y: min(max(p.y - h / 2, b.minY), b.maxY - h) - b.minY, width: w, height: h)
        cfg.showsCursor = true
        let scale = CGFloat(CGDisplayCopyDisplayMode(d.displayID)?.pixelWidth ?? Int(b.width)) / b.width
        cfg.width = Int(w * scale); cfg.height = Int(h * scale)
        guard let img = try? await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(display: d, excludingWindows: []), configuration: cfg),
              let png = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) else { return }
        let name = "\(UUID().uuidString).png"
        try? png.write(to: Self.dir.appending(path: name))
        shots.append(Shot(file: name))
    }

    func clear() {
        shots.forEach { try? FileManager.default.removeItem(at: Self.dir.appending(path: $0.file)) }
        shots = []; done = false
        if jobs.isEmpty { NSApp.terminate(nil) }
    }
}

nonisolated func tapCallback(_: CGEventTapProxy, _ type: CGEventType, _ e: CGEvent,
                             _ info: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let info, type == .leftMouseDown || type == .leftMouseUp else { return Unmanaged.passUnretained(e) }
    let p = e.location, f = e.flags
    let swallow = MainActor.assumeIsolated { Unmanaged<Store>.fromOpaque(info).takeUnretainedValue().handle(type, p, f) }
    return swallow ? nil : Unmanaged.passUnretained(e)
}
