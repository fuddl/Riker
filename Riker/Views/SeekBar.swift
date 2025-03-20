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
            
            // Seek bar
            GeometryReader { geometry in
                let handleSize: CGFloat = 12
                let availableWidth = geometry.size.width - handleSize
                
                ZStack(alignment: .leading) {
                    
                    // Background track
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: isDragging ? 21 : 7)
                        .animation(.easeInOut(duration: 0.2), value: isDragging)
                    
                    // Progress track
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: availableWidth * progress, height: isDragging ? 21 : 7)
                        .animation(.easeInOut(duration: 0.2), value: isDragging)
                
                }
                .clipShape(RoundedRectangle(cornerRadius: 10.5))
                .frame(height: isDragging ? 21 : 7).animation(.easeInOut(duration: 0.2), value: isDragging)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragProgress = min(max(value.location.x / availableWidth, 0), 1)
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
