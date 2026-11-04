import SwiftUI

@main
struct SnoreRecorderApp: App {
    @StateObject private var monitor = SnoreMonitor()
    @StateObject private var store = RecordingStore()
    @StateObject private var player = AudioPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(monitor)
                .environmentObject(store)
                .environmentObject(player)
                .onAppear {
                    store.reload()
                    monitor.onClipSaved = { [weak store] in store?.reload() }
                }
        }
    }
}
