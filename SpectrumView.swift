import SwiftUI

struct SpectrumView: View {
    @ObservedObject var analyzer: UnifiedAudioAnalyser
    
    private let barGradient = Gradient(colors: [
        Color(red: 1.0, green: 0.2, blue: 0.2),
        Color(red: 1.0, green: 0.6, blue: 0.2),
        Color(red: 1.0, green: 1.0, blue: 0.3),
        Color(red: 0.3, green: 1.0, blue: 0.3),
        Color(red: 0.3, green: 0.6, blue: 1.0)
    ])
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    Canvas { context, size in
                        let dbLevels: [Float] = [-20, -40, -60]
                        let dbFloor: Float = -65.0
                        let dbRange: Float = 60.0
                        
                        for level in dbLevels {
                            let y = size.height - CGFloat((level - dbFloor) / dbRange) * size.height
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            
                            context.stroke(path, with: .color(.white.opacity(0.15)), lineWidth: 1)
                            context.draw(Text("\(Int(level))dB").font(.system(size: 8)), at: CGPoint(x: 20, y: y - 8))
                        }
                    }

                    Canvas { context, size in
                        let barCount = analyzer.spectrumBands.count
                        let barWidth = size.width / CGFloat(barCount)
                        
                        for i in 0..<barCount {
                            let amplitude = CGFloat(analyzer.spectrumBands[i])
                            let barHeight = amplitude * size.height
                            let x = CGFloat(i) * barWidth
                            
                            let barRect = CGRect(x: x + 0.5, y: size.height - barHeight, width: barWidth - 1, height: barHeight)
                            
                            context.fill(
                                Path(barRect),
                                with: GraphicsContext.Shading.linearGradient(
                                    barGradient,
                                    startPoint: CGPoint(x: 0, y: size.height),
                                    endPoint: CGPoint(x: 0, y: 0)
                                )
                            )
                            
                            let peak = CGFloat(analyzer.peakHolds[i])
                            let peakY = size.height - (peak * size.height)
                            let peakRect = CGRect(x: x + 0.5, y: peakY, width: barWidth - 1, height: 1)
                            context.fill(Path(peakRect), with: .color(.white.opacity(0.8)))
                        }
                    }

                    Canvas { context, size in
                        let freqs: [Float] = [100, 1000, 5000, 10000]
                        for f in freqs {
                            let xPercentage = log10(f / 20.0) / log10(20000.0 / 20.0)
                            let x = CGFloat(xPercentage) * size.width
                            
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(path, with: .color(.white.opacity(0.1)), lineWidth: 1)
                            
                            let label = f >= 1000 ? "\(Int(f/1000))kHz" : "\(Int(f))Hz"
                            context.draw(Text(label).font(.system(size: 8)).bold(), at: CGPoint(x: x, y: size.height - 10))
                        }
                    }
                }
            }
            .frame(height: 160)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.horizontal)
    }
}
