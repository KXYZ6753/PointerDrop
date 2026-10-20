import SwiftUI

@main struct MyApp: App {
    @StateObject private var s = Store()

    var body: some Scene {
        MenuBarExtra { Panel(s: s) } label: { Icon(s: s) }
            .menuBarExtraStyle(.window)
    }
}

struct Icon: View {
    @ObservedObject var s: Store

    var body: some View {
        if s.done && s.jobs.isEmpty {
            Image(nsImage: greenCheck)
        } else {
            Image(systemName: s.recording ? "record.circle" : s.jobs.isEmpty && !s.running ? "cursorarrow.click" : "clock")
        }
    }

    private var greenCheck: NSImage {
        let i = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(paletteColors: [.systemGreen]))!
        i.isTemplate = false  // menu bar tints template images, which would drop the green
        return i
    }
}

struct Header: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(0.8)
    }
}

struct Row<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).lineLimit(1)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 12))
    }
}

struct Panel: View {
    @ObservedObject var s: Store
    @State private var when = Date().addingTimeInterval(3600)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if s.running { Header("Running") }

            Button {
                s.recording ? s.stopRecording() : s.startRecording()
            } label: {
                Label(s.recording ? "Stop  \(s.draft.count)" : "Record",
                      systemImage: s.recording ? "stop.fill" : "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent).controlSize(.large).tint(s.recording ? .red : .accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Toggle("Block clicks", isOn: $s.blockClicks).toggleStyle(.switch).controlSize(.small)
                Text("Blocks clicks while holding Option").font(.caption2).foregroundStyle(.secondary)
            }

            if !s.draft.isEmpty && !s.recording {
                VStack(alignment: .leading, spacing: 10) {
                    Header("Schedule")
                    DatePicker("", selection: $when, in: Date()...).labelsHidden()
                    HStack {
                        ForEach([1, 2, 4, 8], id: \.self) { h in
                            Button("\(h)h") { when = .now.addingTimeInterval(Double(h) * 3600) }
                                .buttonStyle(.glass).controlSize(.regular)
                        }
                    }
                    HStack {
                        Button { s.schedule(at: when) } label: { Text("Schedule").frame(maxWidth: .infinity) }
                            .buttonStyle(.glassProminent).controlSize(.large)
                        if !s.draftSaved {
                            Button("Save") { s.savePreset() }.buttonStyle(.glass).controlSize(.large)
                        }
                    }
                }
            }

            if !s.jobs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Header("Queue")
                    ForEach(s.jobs) { j in
                        Row(title: j.fire.formatted(.dateTime.month().day().hour().minute()), subtitle: "\(j.clicks.count) clicks") {
                            Button { s.jobs.removeAll { $0.id == j.id } } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !s.presets.isEmpty && !s.recording {
                VStack(alignment: .leading, spacing: 8) {
                    Header("Saved")
                    ForEach(s.presets) { p in
                        Row(title: p.name) {
                            Button { s.presets.removeAll { $0.id == p.id } } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain)
                        }
                        .contentShape(.rect)
                        .onTapGesture { s.load(p) }
                    }
                }
            }

            if s.done {
                VStack(alignment: .leading, spacing: 8) {
                    Header(s.shots.isEmpty ? "Operation completed" : "Log")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(s.shots) { shot in
                            if let i = NSImage(contentsOf: Store.dir.appending(path: shot.file)) {
                                Image(nsImage: i).resizable().scaledToFit().clipShape(.rect(cornerRadius: 8))
                            }
                        }
                    }
                    Button { s.clear() } label: { Text("Clear").frame(maxWidth: .infinity) }
                        .buttonStyle(.glass).controlSize(.large)
                }
            }

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain).foregroundStyle(.secondary).font(.callout)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(18)
        .frame(width: 300)
    }
}
