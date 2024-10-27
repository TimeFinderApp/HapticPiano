import SwiftUI
import CoreHaptics

@main
struct HapticPianoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        KeyboardView(keys: pianoKeys)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
    }
}

struct KeyboardView: View {
    let keys: [PianoKey]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // White keys
                HStack(spacing: 0) {
                    ForEach(whiteKeys) { key in
                        PianoKeyView(key: key, isBlackKey: false)
                            .frame(width: whiteKeyWidth(in: geometry), height: geometry.size.height)
                    }
                }
                // Black keys
                ForEach(blackKeys) { key in
                    if let position = blackKeyPosition(key: key, in: geometry) {
                        SharpKeyView(key: key)
                            .frame(width: blackKeyWidth(in: geometry), height: geometry.size.height * 0.6)
                            .position(x: position, y: geometry.size.height * 0.3)
                    }
                }
            }
        }
    }
    
    // Separate white and black keys for easier processing
    var whiteKeys: [PianoKey] {
        keys.filter { !$0.isSharp }
    }
    
    var blackKeys: [PianoKey] {
        keys.filter { $0.isSharp }
    }
    
    // Calculate widths
    func whiteKeyWidth(in geometry: GeometryProxy) -> CGFloat {
        geometry.size.width / CGFloat(whiteKeys.count)
    }
    
    func blackKeyWidth(in geometry: GeometryProxy) -> CGFloat {
        whiteKeyWidth(in: geometry) * 0.6
    }
    
    // Calculate black key positions
    func blackKeyPosition(key: PianoKey, in geometry: GeometryProxy) -> CGFloat? {
        guard let leftWhiteKey = leftWhiteKey(for: key),
              let leftIndex = whiteKeys.firstIndex(of: leftWhiteKey) else { return nil }
        
        let keyWidth = whiteKeyWidth(in: geometry)
        let position = CGFloat(leftIndex) * keyWidth + keyWidth * 0.75
        return position
    }
    
    // Map black keys to their corresponding left white keys
    func leftWhiteKey(for blackKey: PianoKey) -> PianoKey? {
        switch blackKey.note {
        case "F#2": return keys.first { $0.note == "F2" }
        case "G#2": return keys.first { $0.note == "G2" }
        case "A#2": return keys.first { $0.note == "A2" }
        case "C#3": return keys.first { $0.note == "C3" }
        case "D#3": return keys.first { $0.note == "D3" }
        case "F#3": return keys.first { $0.note == "F3" }
        case "G#3": return keys.first { $0.note == "G3" }
        default: return nil
        }
    }
}

struct PianoKeyView: View {
    let key: PianoKey
    let isBlackKey: Bool
    @State private var isPressed = false
    @State private var engine: CHHapticEngine?
    @State private var player: CHHapticAdvancedPatternPlayer?
    
    var body: some View {
        Rectangle()
            .fill(isPressed ? Color.white.opacity(0.6) : Color.white)
            .border(Color.black, width: 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            prepareHaptics()
                            playHaptic(for: key)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        stopHaptic()
                    }
            )
            .onAppear {
                prepareHaptics()
                setupNotificationObservers()
            }
            .onDisappear {
                removeNotificationObservers()
            }
    }
    
    // Prepare and create haptic engine
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Failed to create the haptic engine: \(error.localizedDescription)")
        }
    }

    // Play haptic feedback for key
    func playHaptic(for key: PianoKey) {
        guard let engine = engine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(key.sharpness))
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpnessParam], relativeTime: 0, duration: 100)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            player = try engine.makeAdvancedPlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error.localizedDescription)")
        }
    }

    // Stop haptic feedback
    func stopHaptic() {
        do {
            try player?.stop(atTime: 0)
            player = nil
        } catch {
            print("Failed to stop haptic: \(error.localizedDescription)")
        }
    }
    
    // Setup notification observers for app lifecycle
    func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            prepareHaptics() // Recreate haptic engine when app becomes active
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            stopHaptic() // Stop haptic engine when app enters background
        }
    }
    
    // Remove notification observers
    func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
}

struct SharpKeyView: View {
    let key: PianoKey
    @State private var isPressed = false
    @State private var engine: CHHapticEngine?
    @State private var player: CHHapticAdvancedPatternPlayer?
    
    var body: some View {
        Rectangle()
            .fill(isPressed ? Color.black.opacity(0.6) : Color.black)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            prepareHaptics()
                            playHaptic(for: key)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        stopHaptic()
                    }
            )
            .zIndex(1)
            .onAppear {
                prepareHaptics()
                setupNotificationObservers()
            }
            .onDisappear {
                removeNotificationObservers()
            }
    }
    
    // Prepare and create haptic engine
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Failed to create the haptic engine: \(error.localizedDescription)")
        }
    }

    // Play haptic feedback for key
    func playHaptic(for key: PianoKey) {
        guard let engine = engine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(key.sharpness))
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpnessParam], relativeTime: 0, duration: 0.1)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            player = try engine.makeAdvancedPlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error.localizedDescription)")
        }
    }

    // Stop haptic feedback
    func stopHaptic() {
        do {
            try player?.stop(atTime: 0)
            player = nil
        } catch {
            print("Failed to stop haptic: \(error.localizedDescription)")
        }
    }
    
    // Setup notification observers for app lifecycle
    func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            prepareHaptics() // Recreate haptic engine when app becomes active
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            stopHaptic() // Stop haptic engine when app enters background
        }
    }
    
    // Remove notification observers
    func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
}

// Define the piano keys in the correct order
let pianoKeys: [PianoKey] = [
    PianoKey(note: "E2", frequency: 82.41, sharpness: 0.022, isSharp: false),
    PianoKey(note: "F2", frequency: 87.31, sharpness: 0.085, isSharp: false),
    PianoKey(note: "F#2", frequency: 92.50, sharpness: 0.144, isSharp: true),
    PianoKey(note: "G2", frequency: 98.00, sharpness: 0.200, isSharp: false),
    PianoKey(note: "G#2", frequency: 103.83, sharpness: 0.255, isSharp: true),
    PianoKey(note: "A2", frequency: 110.00, sharpness: 0.309, isSharp: false),
    PianoKey(note: "A#2", frequency: 116.54, sharpness: 0.362, isSharp: true),
    PianoKey(note: "B2", frequency: 123.47, sharpness: 0.415, isSharp: false),
    PianoKey(note: "C3", frequency: 130.81, sharpness: 0.468, isSharp: false),
    PianoKey(note: "C#3", frequency: 138.59, sharpness: 0.520, isSharp: true),
    PianoKey(note: "D3", frequency: 146.83, sharpness: 0.573, isSharp: false),
    PianoKey(note: "D#3", frequency: 155.56, sharpness: 0.626, isSharp: true),
    PianoKey(note: "E3", frequency: 164.81, sharpness: 0.680, isSharp: false),
    PianoKey(note: "F3", frequency: 174.61, sharpness: 0.734, isSharp: false),
    PianoKey(note: "F#3", frequency: 185.00, sharpness: 0.788, isSharp: true),
    PianoKey(note: "G3", frequency: 196.00, sharpness: 0.844, isSharp: false),
    PianoKey(note: "G#3", frequency: 207.65, sharpness: 0.900, isSharp: true),
    PianoKey(note: "A3", frequency: 220.00, sharpness: 0.957, isSharp: false)
]

struct PianoKey: Identifiable, Equatable {
    let id = UUID()
    let note: String
    let frequency: Double
    let sharpness: Double
    let isSharp: Bool
}

// Implement Equatable conformance to compare PianoKey instances
extension PianoKey {
    static func == (lhs: PianoKey, rhs: PianoKey) -> Bool {
        lhs.id == rhs.id
    }
}
