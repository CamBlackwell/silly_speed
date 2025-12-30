import SwiftUI

struct GoniometerView: View {
    @ObservedObject var analyzer: UnifiedAudioAnalyser

    var body: some View {
        VStack(spacing: 4) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 10

                var crosshairPath = Path()
                crosshairPath.move(to: CGPoint(x: center.x - radius, y: center.y))
                crosshairPath.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                crosshairPath.move(to: CGPoint(x: center.x, y: center.y - radius))
                crosshairPath.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                context.stroke(crosshairPath, with: .color(.white.opacity(0.2)), lineWidth: 1)

                var diagonalPath = Path()
                let diagLength = radius * 0.7
                diagonalPath.move(to: CGPoint(x: center.x - diagLength, y: center.y - diagLength))
                diagonalPath.addLine(to: CGPoint(x: center.x + diagLength, y: center.y + diagLength))
                diagonalPath.move(to: CGPoint(x: center.x - diagLength, y: center.y + diagLength))
                diagonalPath.addLine(to: CGPoint(x: center.x + diagLength, y: center.y - diagLength))
                context.stroke(diagonalPath, with: .color(.white.opacity(0.1)), lineWidth: 1)

                let leftSamples = analyzer.leftSamples
                let rightSamples = analyzer.rightSamples
                let count = min(leftSamples.count, rightSamples.count)

                for i in 0..<count {
                    let left = leftSamples[i]
                    let right = rightSamples[i]
                    let mid = (left + right) / 2
                    let side = (left - right) / 2
                    
                    let x = center.x + CGFloat(side) * radius
                    let y = center.y - CGFloat(mid) * radius
                    let alpha = Float(i) / Float(count)
                    
                    let pointRect = CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)
                    context.fill(
                        Path(ellipseIn: pointRect),
                        with: .color(Color.red.opacity(Double(alpha * 0.8)))
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))

                    let normalizedValue = (analyzer.phaseCorrelation + 1) / 2
                    Rectangle()
                        .fill(phaseColor)
                        .frame(width: geometry.size.width * CGFloat(normalizedValue))

                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 2)
                        .offset(x: geometry.size.width / 2)
                }
            }
            .frame(height: 4)
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.horizontal)
    }

    private var phaseColor: Color {
        if analyzer.phaseCorrelation > 0.5 { return .green }
        else if analyzer.phaseCorrelation > 0 { return .yellow }
        else if analyzer.phaseCorrelation > -0.5 { return .orange }
        else { return .red }
    }
}
