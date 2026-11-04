import SwiftUI

struct ContentView: View {
    @EnvironmentObject var monitor: SnoreMonitor
    @EnvironmentObject var store: RecordingStore
    @EnvironmentObject var player: AudioPlayer
    @State private var confirmDeleteAll = false

    var body: some View {
        NavigationStack {
            List {
                Section { monitorCard }

                if store.recordings.isEmpty {
                    Section {
                        Text("Još nema snimaka. Pokreni praćenje, ostavi mobitel pored kreveta (na punjaču) i zaključaj ekran.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(groupedByNight, id: \.title) { group in
                        Section("\(group.title) · \(group.items.count) snimaka") {
                            ForEach(group.items) { rec in
                                RecordingRow(recording: rec,
                                             isPlaying: player.playingURL == rec.url) {
                                    player.toggle(rec.url)
                                }
                            }
                            .onDelete { idx in
                                idx.map { group.items[$0] }.forEach { rec in
                                    if player.playingURL == rec.url { player.stop() }
                                    store.delete(rec)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hrkanje")
            .toolbar {
                if !store.recordings.isEmpty {
                    Button("Obriši sve", role: .destructive) { confirmDeleteAll = true }
                }
            }
            .confirmationDialog("Obrisati sve snimke?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Obriši sve", role: .destructive) { player.stop(); store.deleteAll() }
            }
            .alert("Greška", isPresented: Binding(get: { monitor.errorMessage != nil },
                                                  set: { if !$0 { monitor.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(monitor.errorMessage ?? "")
            }
        }
    }

    private var monitorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(monitor.isRecordingClip ? Color.red : (monitor.isRunning ? Color.green : Color.gray))
                    .frame(width: 10, height: 10)
                Text(statusText).font(.headline)
            }

            if monitor.isRunning {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Snoring")
                        Spacer()
                        Text(String(format: "%.2f", monitor.currentConfidence)).monospacedDigit()
                    }
                    .font(.subheadline)
                    ProgressView(value: min(max(monitor.currentConfidence, 0), 1))
                        .tint(monitor.currentConfidence >= monitor.threshold ? Color.red : Color.accentColor)
                    Text("Prag: \(String(format: "%.1f", monitor.threshold))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Button {
                if monitor.isRunning {
                    monitor.stop()
                    store.reload()
                } else {
                    player.stop()
                    monitor.start()
                }
            } label: {
                Label(monitor.isRunning ? "Zaustavi" : "Pokreni praćenje",
                      systemImage: monitor.isRunning ? "stop.fill" : "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(monitor.isRunning ? Color.red : Color.accentColor)
            .controlSize(.large)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        if monitor.isRecordingClip { return "Hrkanje – snimam…" }
        return monitor.isRunning ? "Slušam" : "Zaustavljeno"
    }

    private var groupedByNight: [(title: String, items: [Recording])] {
        // A "night" runs from noon to noon, so 23:50 and 02:10 land in the same group.
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        let groups = Dictionary(grouping: store.recordings) { rec in
            cal.startOfDay(for: rec.start.addingTimeInterval(-12 * 3600))
        }
        return groups.keys.sorted(by: >).map { day in
            (title: "Noć \(df.string(from: day))", items: groups[day]!.sorted { $0.start > $1.start })
        }
    }
}

struct RecordingRow: View {
    let recording: Recording
    let isPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(isPlaying ? Color.red : Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recording.start, format: .dateTime.hour().minute().second())
                        .font(.body.monospacedDigit())
                    HStack(spacing: 8) {
                        Text(durationText)
                        if let peak = recording.peakConfidence {
                            Text("max \(String(format: "%.2f", peak))")
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                ShareLink(item: recording.url) { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(.borderless)
            }
        }
        .buttonStyle(.plain)
    }

    private var durationText: String {
        let s = Int(recording.duration.rounded())
        return s >= 60 ? "\(s / 60) min \(s % 60) s" : "\(s) s"
    }
}
