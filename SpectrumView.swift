import SwiftUI

struct SpectrumView: View {
    @ObservedObject var analyzer: UnifiedAudioAnalyser
    
    private let gradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.2, blue: 0.2),
            Color(red: 1.0, green: 0.6, blue: 0.2),
            Color(red: 1.0, green: 1.0, blue: 0.3),
            Color(red: 0.3, green: 1.0, blue: 0.3),
            Color(red: 0.3, green: 0.6, blue: 1.0),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geo in
                Canvas { context, size in
                    let barCount = analyzer.spectrumBands.count
                    let barWidth = size.width / CGFloat(barCount)
                    let spacing: CGFloat = 1
                    
                    for i in 0..<barCount {
                        let amplitude = CGFloat(analyzer.spectrumBands[i])
                        let peak = CGFloat(analyzer.peakHolds[i])
                        let barHeight = amplitude * size.height
                        let peakY = size.height - (peak * size.height)
                        
                        let x = CGFloat(i) * barWidth
                        
                        let barRect = CGRect(
                            x: x + spacing / 2,
                            y: size.height - barHeight,
                            width: barWidth - spacing,
                            height: barHeight
                        )
                        
                        let barPath = RoundedRectangle(cornerRadius: 1)
                            .path(in: barRect)
                        
                        let colorPosition = CGFloat(i) / CGFloat(barCount)
                        let barColor = gradientColor(at: colorPosition)
                        
                        context.fill(barPath, with: .color(barColor.opacity(0.9)))
                        context.fill(barPath, with: .color(barColor.opacity(0.3)))
                        
                        if peak > 0.05 {
                            let peakRect = CGRect(
                                x: x + spacing / 2,
                                y: peakY - 1,
                                width: barWidth - spacing,
                                height: 2
                            )
                            context.fill(
                                Path(roundedRect: peakRect, cornerRadius: 1),
                                with: .color(.white.opacity(0.9))
                            )
                        }
                    }
                    
                    let labels = ["20Hz", "100Hz", "1kHz", "10kHz", "20kHz"]
                    let positions: [CGFloat] = [0.0, 0.15, 0.5, 0.85, 1.0]
                    
                    for (label, position) in zip(labels, positions) {
                        let x = position * size.width
                        let point = CGPoint(x: x, y: size.height + 12)
                        context.draw(
                            Text(label)
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary),
                            at: point
                        )
                    }
                }
            }
            .frame(height: 120)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal)
    }
    
    private func gradientColor(at position: CGFloat) -> Color {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.2, blue: 0.2),
            Color(red: 1.0, green: 0.6, blue: 0.2),
            Color(red: 1.0, green: 1.0, blue: 0.3),
            Color(red: 0.3, green: 1.0, blue: 0.3),
            Color(red: 0.3, green: 0.6, blue: 1.0),
        ]
        
        let scaledPosition = position * CGFloat(colors.count - 1)
        let index = Int(scaledPosition)
        let fraction = scaledPosition - CGFloat(index)
        
        guard index < colors.count - 1 else { return colors.last! }
        
        return colors[index]
    }
}
