import SwiftUI
import AudioKit
import AudioKitUI

struct SpectrumView: View {
    @ObservedObject var manager: SpectrumManager
    
    // Minimeters Style Gradient: Cold (Bottom) to Hot (Top)
    // You can adjust these colors to match your preferred theme
    private let minimetersGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 255/255, green: 50/255, blue: 50/255),   // Red (Clipping)
            Color(red: 255/255, green: 200/255, blue: 50/255),  // Yellow (Loud)
            Color(red: 50/255, green: 200/255, blue: 100/255),  // Green (Good)
            Color(red: 50/255, green: 100/255, blue: 255/255)   // Blue (Quiet)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        VStack {
            ZStack {
                // Background
                Color.black
                
                if let node = manager.node {
                    // THE CORE VISUALIZATION
                    // We use the spectrum as a MASK.
                    // This creates the "Level Meter" effect where the bar color
                    // is determined by its height, not its frequency.
                    minimetersGradient
                        .mask(
                            NodeFFTView(node)
                                .padding(.top, 2) // Slight padding to avoid clipping top edge
                        )
                } else {
                    // Loading State
                    Text("Initialize Audio Engine")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Overlay the Grid (Hz/kHz)
                FrequencyGridOverlay()
            }
            // Container Styling
            .frame(height: 160)
            .cornerRadius(8)
            // The "Minimeters" white border
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
}

// Your original grid logic, optimized for SwiftUI
struct FrequencyGridOverlay: View {
    let freqs: [(String, Float)] = [("100", 100), ("1k", 1000), ("5k", 5000), ("10k", 10000)]
    
    var body: some View {
        GeometryReader { geo in
            ForEach(freqs, id: \.1) { (label, freq) in
                // Calculate position (Logarithmic)
                let xPercent = log10(freq / 20.0) / log10(20000.0 / 20.0)
                let xPos = CGFloat(xPercent) * geo.size.width
                
                // Draw Line
                Path { path in
                    path.move(to: CGPoint(x: xPos, y: 0))
                    path.addLine(to: CGPoint(x: xPos, y: geo.size.height))
                }
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                
                // Draw Label
                Text(label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .position(x: xPos + 10, y: geo.size.height - 10)
            }
        }
        .allowsHitTesting(false) // Pass touches through to controls below
    }
}
