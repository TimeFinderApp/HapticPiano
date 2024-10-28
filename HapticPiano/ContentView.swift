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
    
    @State private var pressedKeys: Set<PianoKey> = []
    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let totalHeight = geometry.size.height
            
            ZStack(alignment: .leading) {
                // White keys
                HStack(spacing: 0) {
                    ForEach(whiteKeys) { key in
                        PianoKeyView(key: key, isBlackKey: false, pressedKeys: $pressedKeys)
                            .frame(width: whiteKeyWidth(totalWidth: totalWidth), height: totalHeight)
                    }
                }
                // Black keys
                ForEach(blackKeys) { key in
                    if let position = blackKeyPosition(key: key, totalWidth: totalWidth) {
                        SharpKeyView(key: key, pressedKeys: $pressedKeys)
                            .frame(width: blackKeyWidth(totalWidth: totalWidth), height: totalHeight * 0.6)
                            .position(x: position, y: totalHeight * 0.3)
                    }
                }
            }
            .overlay(
                MultiTouchView { touchPoints in
                    DispatchQueue.main.async {
                        self.pressedKeys = Set(touchPoints.compactMap { point in
                            self.keyAt(location: point, totalWidth: totalWidth, totalHeight: totalHeight)
                        })
                    }
                }
            )
        }
    }

    // Find which key corresponds to the touch location
    func keyAt(location: CGPoint, totalWidth: CGFloat, totalHeight: CGFloat) -> PianoKey? {
        let whiteKeyWidth = totalWidth / CGFloat(whiteKeys.count)

        // Check if touch is on black keys first
        for key in blackKeys {
            if let position = blackKeyPosition(key: key, totalWidth: totalWidth),
               abs(location.x - position) < blackKeyWidth(totalWidth: totalWidth) / 2,
               location.y < totalHeight * 0.6 {
                return key
            }
        }

        // Touch is on white keys
        let whiteIndex = Int(location.x / whiteKeyWidth)
        if whiteIndex < whiteKeys.count {
            return whiteKeys[whiteIndex]
        }

        return nil
    }

    // Separate white and black keys for easier processing
    var whiteKeys: [PianoKey] {
        keys.filter { !$0.isSharp }
    }

    var blackKeys: [PianoKey] {
        keys.filter { $0.isSharp }
    }

    // Calculate widths
    func whiteKeyWidth(totalWidth: CGFloat) -> CGFloat {
        totalWidth / CGFloat(whiteKeys.count)
    }

    func blackKeyWidth(totalWidth: CGFloat) -> CGFloat {
        whiteKeyWidth(totalWidth: totalWidth) * 0.6
    }

    // Adjusted black key positions to center them between white keys
    func blackKeyPosition(key: PianoKey, totalWidth: CGFloat) -> CGFloat? {
        guard let leftWhiteKey = leftWhiteKey(for: key),
              let leftIndex = whiteKeys.firstIndex(of: leftWhiteKey) else { return nil }

        let keyWidth = whiteKeyWidth(totalWidth: totalWidth)
        let position = (CGFloat(leftIndex) + 0.75) * keyWidth
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
    @Binding var pressedKeys: Set<PianoKey>
    @State private var isPlayingSound = false
    @State private var engine: CHHapticEngine?
    @State private var player: CHHapticAdvancedPatternPlayer?

    var body: some View {
        Rectangle()
            .fill(pressedKeys.contains(key) ? Color.white.opacity(0.6) : Color.white)
            .border(Color.black, width: 1)
            .onChange(of: pressedKeys) { newPressedKeys in
                let isPressed = newPressedKeys.contains(key)
                if isPressed && !isPlayingSound {
                    playHaptic(for: key)
                    playSound(for: key)
                    isPlayingSound = true
                } else if !isPressed && isPlayingSound {
                    stopHaptic()
                    stopSound()
                    isPlayingSound = false
                }
            }
            .onAppear {
                prepareHaptics()
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
        // Increase duration to ensure the haptic feedback continues while the key is pressed
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpnessParam], relativeTime: 0, duration: 100.0)

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

    // Function to simulate playing a sound when a key is pressed
    func playSound(for key: PianoKey) {
        print("Playing sound for \(key.note)")
    }

    // Function to simulate stopping a sound when a key is released
    func stopSound() {
        print("Stopping sound")
    }
}

struct SharpKeyView: View {
    let key: PianoKey
    @Binding var pressedKeys: Set<PianoKey>
    @State private var isPlayingSound = false
    @State private var engine: CHHapticEngine?
    @State private var player: CHHapticAdvancedPatternPlayer?

    var body: some View {
        Rectangle()
            .fill(pressedKeys.contains(key) ? Color.black.opacity(0.6) : Color.black)
            .onChange(of: pressedKeys) { newPressedKeys in
                let isPressed = newPressedKeys.contains(key)
                if isPressed && !isPlayingSound {
                    playHaptic(for: key)
                    playSound(for: key)
                    isPlayingSound = true
                } else if !isPressed && isPlayingSound {
                    stopHaptic()
                    stopSound()
                    isPlayingSound = false
                }
            }
            .onAppear {
                prepareHaptics()
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
        // Increase duration to ensure the haptic feedback continues while the key is pressed
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpnessParam], relativeTime: 0, duration: 100.0)

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

    // Function to simulate playing a sound when a key is pressed
    func playSound(for key: PianoKey) {
        print("Playing sound for \(key.note)")
    }

    // Function to simulate stopping a sound when a key is released
    func stopSound() {
        print("Stopping sound")
    }
}

// Define the piano keys in the correct order
let pianoKeys: [PianoKey] = [
    PianoKey(note: "E2", frequency: 82.41, sharpness: 0.032, isSharp: false),
    PianoKey(note: "F2", frequency: 87.31, sharpness: 0.092, isSharp: false),
    PianoKey(note: "F#2", frequency: 92.50, sharpness: 0.149, isSharp: true),
    PianoKey(note: "G2", frequency: 98.00, sharpness: 0.204, isSharp: false),
    PianoKey(note: "G#2", frequency: 103.83, sharpness: 0.258, isSharp: true),
    PianoKey(note: "A2", frequency: 110.00, sharpness: 0.312, isSharp: false),
    PianoKey(note: "A#2", frequency: 116.54, sharpness: 0.365, isSharp: true),
    PianoKey(note: "B2", frequency: 123.47, sharpness: 0.418, isSharp: false),
    PianoKey(note: "C3", frequency: 130.81, sharpness: 0.471, isSharp: false),
    PianoKey(note: "C#3", frequency: 138.59, sharpness: 0.523, isSharp: true),
    PianoKey(note: "D3", frequency: 146.83, sharpness: 0.576, isSharp: false),
    PianoKey(note: "D#3", frequency: 155.56, sharpness: 0.629, isSharp: true),
    PianoKey(note: "E3", frequency: 164.81, sharpness: 0.683, isSharp: false),
    PianoKey(note: "F3", frequency: 174.61, sharpness: 0.737, isSharp: false),
    PianoKey(note: "F#3", frequency: 185.00, sharpness: 0.791, isSharp: true),
    PianoKey(note: "G3", frequency: 196.00, sharpness: 0.847, isSharp: false),
    PianoKey(note: "G#3", frequency: 207.65, sharpness: 0.903, isSharp: true),
    PianoKey(note: "A3", frequency: 220.00, sharpness: 0.960, isSharp: false)
]

struct PianoKey: Identifiable {
    let id = UUID() // Optional: you can remove 'id' if not needed
    let note: String
    let frequency: Double
    let sharpness: Double
    let isSharp: Bool
}

// Implement Equatable and Hashable based on 'note'
extension PianoKey: Equatable, Hashable {
    static func == (lhs: PianoKey, rhs: PianoKey) -> Bool {
        return lhs.note == rhs.note
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(note)
    }
}

// UIViewRepresentable to handle multi-touch
struct MultiTouchView: UIViewRepresentable {
    var touchHandler: ([CGPoint]) -> Void

    func makeUIView(context: Context) -> TouchReportingView {
        let view = TouchReportingView()
        view.touchHandler = touchHandler
        return view
    }

    func updateUIView(_ uiView: TouchReportingView, context: Context) {
        uiView.touchHandler = touchHandler
    }
}
class TouchReportingView: UIView {
    var touchHandler: (([CGPoint]) -> Void)?
    private var activeTouches: [UITouch: CGPoint] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeTouches[touch] = touch.location(in: self)
        }
        reportActiveTouches()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeTouches[touch] = touch.location(in: self)
        }
        reportActiveTouches()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeTouches.removeValue(forKey: touch)
        }
        reportActiveTouches()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeTouches.removeValue(forKey: touch)
        }
        reportActiveTouches()
    }

    private func reportActiveTouches() {
        let points = Array(activeTouches.values)
        touchHandler?(points)
    }
}
