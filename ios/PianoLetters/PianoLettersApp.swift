import SwiftUI
import AVFoundation

@main
struct PianoLettersApp: App {
    init() {
        // Sound plays even when the iPad is in Silent Mode.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var page = PageController()

    var body: some View {
        PageView(page: page)
            .ignoresSafeArea()
            .background(Color(red: 0.086, green: 0.094, blue: 0.110).ignoresSafeArea())
            .persistentSystemOverlays(.hidden)
            .preferredColorScheme(.dark) // light status bar text on the dark top bar
            .onOpenURL { url in page.openFile(url) }
    }
}
