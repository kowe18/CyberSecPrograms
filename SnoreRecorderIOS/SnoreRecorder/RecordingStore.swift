import AVFoundation
import Foundation

struct RecordingMeta: Codable {
    var start: Date
    var duration: Double
    var peakConfidence: Double
}

struct Recording: Identifiable, Hashable {
    let url: URL
    let start: Date
    let duration: Double
    let peakConfidence: Double?
    var id: URL { url }
}

/// Clips live in Documents/Recordings as `snore_yyyyMMdd_HHmmss.m4a`
/// with a `.json` sidecar holding start time, duration and peak confidence.
/// They're also visible in the Files app (On My iPhone → Hrkanje).
final class RecordingStore: ObservableObject {
    @Published private(set) var recordings: [Recording] = []

    static let directory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let nameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()

    static func fileName(for date: Date) -> String {
        "snore_\(nameFormatter.string(from: date)).m4a"
    }

    static func writeMeta(_ meta: RecordingMeta, for audioURL: URL) {
        let url = audioURL.deletingPathExtension().appendingPathExtension("json")
        if let data = try? JSONEncoder().encode(meta) { try? data.write(to: url, options: .atomic) }
    }

    func reload() {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: nil)) ?? []
        let items: [Recording] = files.filter { $0.pathExtension == "m4a" }.compactMap { url in
            let metaURL = url.deletingPathExtension().appendingPathExtension("json")
            if let data = try? Data(contentsOf: metaURL),
               let meta = try? JSONDecoder().decode(RecordingMeta.self, from: data) {
                return Recording(url: url, start: meta.start, duration: meta.duration,
                                 peakConfidence: meta.peakConfidence)
            }
            // No sidecar (e.g. app was killed mid-clip): fall back to filename + file length.
            let name = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "snore_", with: "")
            let start = Self.nameFormatter.date(from: name) ?? Date.distantPast
            var duration = 0.0
            if let f = try? AVAudioFile(forReading: url) {
                duration = Double(f.length) / f.fileFormat.sampleRate
            }
            return Recording(url: url, start: start, duration: duration, peakConfidence: nil)
        }
        recordings = items.sorted { $0.start > $1.start }
    }

    func delete(_ recording: Recording) {
        try? FileManager.default.removeItem(at: recording.url)
        try? FileManager.default.removeItem(at: recording.url.deletingPathExtension().appendingPathExtension("json"))
        reload()
    }

    func deleteAll() {
        recordings.forEach { delete($0) }
    }
}
