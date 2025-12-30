import SwiftUI

struct SpectrumView: View {
    @ObservedObject var manager: SpectrumManager
    
    private let gradient = Gradient(colors: [.red, .orange, .yellow, .green])
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SPECTRUM")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            GeometryReader { geo in
                Canvas { context, size in
                    let barWidth = size.width / CGFloat(manager.amplitudes.count)
                    
                    for i in 0..<manager.amplitudes.count {
                        let x = CGFloat(i) * barWidth
                        let barHeight = CGFloat(manager.amplitudes[i]) * size.height
                        let peakY = size.height - (CGFloat(manager.peaks[i]) * size.height)
                        
                        // Draw Main Bar
                        let rect = CGRect(x: x + 1, y: size.height - barHeight, width: barWidth - 1, height: barHeight)
                        context.fill(Path(rect), with: .linearGradient(gradient, startPoint: .init(x: 0, y: 0), endPoint: .init(x: 0, y: size.height)))
                        
                        // Draw Peak Line (White)
                        let peakRect = CGRect(x: x + 1, y: peakY, width: barWidth - 1, height: 1.5)
                        context.fill(Path(peakRect), with: .color(.white))
                    }
                }
            }
            .frame(height: 80)
            .background(Color.black.opacity(0.2))
            .cornerRadius(4)
        }
        .padding(.horizontal)
    }
}
