import SwiftUI
import MediaPlayer

struct TrackRowView: View {
    let item: MPMediaItem
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let metadata: MusicBrainzMetadata?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.title ?? "Unknown Track")
                        .foregroundColor(isCurrentTrack ? .accentColor : .primary)
                        .fontWeight(isCurrentTrack ? .semibold : .regular)
                        .multilineTextAlignment(.leading)
                    Text(item.artist ?? "Unknown Artist")
                        .font(.subheadline)
                        .foregroundColor(isCurrentTrack ? .accentColor.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if isCurrentTrack && isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.accentColor)
                    }
                    Text(formatDuration(item.playbackDuration))
                        .font(.subheadline)
                        .foregroundColor(isCurrentTrack ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
} 
