import SwiftUI

struct GoniometerView: View {
    @ObservedObject var manager: GoniometerManager
    
    var body: some View {
        VStack(spacing: 10) {
            // Goniometer display
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 10
                
                // Draw circle boundary
                context.stroke(
                    Path(ellipseIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color(.white.opacity(0.3)),
                    lineWidth: 1
                )
                
                // Draw center lines
                var path = Path()
                path.move(to: CGPoint(x: center.x - radius, y: center.y))
                path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                path.move(to: CGPoint(x: center.x, y: center.y - radius))
                path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                context.stroke(path, with: .color(.white.opacity(0.2)), lineWidth: 1)
                
                // Draw diagonal lines (±45°)
                var diagonalPath = Path()
                diagonalPath.move(to: CGPoint(x: center.x - radius * 0.7, y: center.y - radius * 0.7))
                diagonalPath.addLine(to: CGPoint(x: center.x + radius * 0.7, y: center.y + radius * 0.7))
                diagonalPath.move(to: CGPoint(x: center.x - radius * 0.7, y: center.y + radius * 0.7))
                diagonalPath.addLine(to: CGPoint(x: center.x + radius * 0.7, y: center.y - radius * 0.7))
                context.stroke(diagonalPath, with: .color(.white.opacity(0.1)), lineWidth: 1)
                
                // Draw audio points
                let leftSamples = manager.leftSamples
                let rightSamples = manager.rightSamples
                let count = min(leftSamples.count, rightSamples.count)
                
                for i in 0..<count {
                    let left = leftSamples[i]
                    let right = rightSamples[i]
                    
                    // Convert to mid-side
                    let mid = (left + right) / 2
                    let side = (left - right) / 2
                    
                    // Map to screen coordinates
                    let x = center.x + CGFloat(side) * radius
                    let y = center.y - CGFloat(mid) * radius  // Negative because Y increases downward
                    
                    // Fade older points
                    let alpha = Float(i) / Float(count)
                    
                    // Draw point
                    let pointRect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                    context.fill(
                        Path(ellipseIn: pointRect),
                        with: .color(.red.opacity(Double(alpha * 0.8)))
                    )
                }
            }
            .frame(height: 200)
            .background(Color.black.opacity(0.3))
            .cornerRadius(10)
            
            // Phase correlation meter
            phaseCorrelationMeter
        }
        .padding(.horizontal)
    }
    
    private var phaseCorrelationMeter: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Phase Correlation")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f", manager.phaseCorrelation))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(phaseColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                    
                    // Correlation bar
                    let normalizedValue = (manager.phaseCorrelation + 1) / 2  // Map -1...1 to 0...1
                    Rectangle()
                        .fill(phaseColor)
                        .frame(width: geometry.size.width * CGFloat(normalizedValue))
                    
                    // Center line (0)
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 2)
                        .offset(x: geometry.size.width / 2)
                }
            }
            .frame(height: 20)
            .cornerRadius(4)
            
            HStack {
                Text("-1")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("0")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("+1")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var phaseColor: Color {
        if manager.phaseCorrelation > 0.5 {
            return .green
        } else if manager.phaseCorrelation > 0 {
            return .yellow
        } else if manager.phaseCorrelation > -0.5 {
            return .orange
        } else {
            return .red
        }
    }
}
