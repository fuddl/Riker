import SwiftUI

struct SeekBar: View {
    let duration: TimeInterval
    let currentTime: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    private var progress: Double {
        isDragging ? dragProgress : duration > 0 ? currentTime / duration : 0
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Time labels
            HStack {
                Text(timeString(for: currentTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(timeString(for: duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Seek bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 2)
                    
                    // Progress track
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * progress, height: 2)
                    
                    // Knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .position(x: geometry.size.width * progress, y: geometry.size.height / 2)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                        }
                        .onEnded { _ in
                            isDragging = false
                            onSeek(dragProgress * duration)
                        }
                )
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
    }
    
    private func timeString(for time: TimeInterval) -> String {
        let minutes = Int(time / 60)
        let seconds = Int(time.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
} 