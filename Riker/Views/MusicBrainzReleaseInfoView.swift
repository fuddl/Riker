import SwiftUI

struct MusicBrainzReleaseInfoView: View {
    let releaseGroup: MusicBrainzClient.ReleaseGroup?
    let release: MusicBrainzClient.Release?
    let isLoading: Bool
    
    var body: some View {
        if isLoading {
            ProgressView()
                .progressViewStyle(.circular)
        } else if let releaseGroup = releaseGroup {
            VStack(alignment: .leading, spacing: 16) {
                // Release Group Info
                Group {
                    Text("Release Group")
                        .font(.headline)
                    
                    if let title = releaseGroup.title {
                        MetadataRow(key: "Title", value: title)
                    }
                    
                    if let firstReleaseDate = releaseGroup.firstReleaseDate {
                        MetadataRow(key: "First Release", value: firstReleaseDate)
                    }
                    
                    if let type = releaseGroup.type {
                        MetadataRow(key: "Type", value: type)
                    }
                    
                    if let artistCredit = releaseGroup.artistCredit {
                        let artists = artistCredit.map { $0.name + ($0.joinPhrase ?? "") }.joined()
                        MetadataRow(key: "Artists", value: artists)
                    }
                }
                
                // Tags
                if let tags = releaseGroup.tags, !tags.isEmpty {
                    Group {
                        Text("Tags")
                            .font(.headline)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.name) { tag in
                                Text(tag.name)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Genres
                if let genres = releaseGroup.genres, !genres.isEmpty {
                    Group {
                        Text("Genres")
                            .font(.headline)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(genres, id: \.name) { genre in
                                Text(genre.name)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Rating
                if let rating = releaseGroup.rating,
                   let votesCount = rating.votesCount,
                   votesCount > 0 {         
                    VStack {
                        Text("Rating")
                            .font(.headline)
                        if let value = rating.value {
                            let roundedValue = round(value * 2) / 2 // Round to nearest 0.5
                            let fullStars = Int(roundedValue)
                            let hasHalfStar = roundedValue.truncatingRemainder(dividingBy: 1) != 0
                            let emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0)
                            
                            let stars = String(repeating: "★", count: fullStars) +
                                       (hasHalfStar ? "⯨" : "") +
                                       String(repeating: "☆", count: emptyStars)
                            Text(stars)
                                .font(.subheadline)
                        }
                        
                        Text("Based on \(votesCount) votes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Release Info
                if let release = release {
                    Group {
                        Text("Release")
                            .font(.headline)
                        
                        if let title = release.title {
                            MetadataRow(key: "Title", value: title)
                        }
                        
                        if let date = release.date {
                            MetadataRow(key: "Date", value: date)
                        }
                        
                        if let country = release.country {
                            MetadataRow(key: "Country", value: country)
                        }
                        
                        if let status = release.status {
                            MetadataRow(key: "Status", value: status)
                        }
                        
                        if let labelInfo = release.labelInfo {
                            ForEach(labelInfo, id: \.catalogNumber) { info in
                                if let label = info.label {
                                    MetadataRow(key: "Label", value: label.name)
                                }
                                if let catalogNumber = info.catalogNumber {
                                    MetadataRow(key: "Catalog Number", value: catalogNumber)
                                }
                            }
                        }
                        
                        if let media = release.media {
                            ForEach(media, id: \.format) { medium in
                                if let format = medium.format {
                                    MetadataRow(key: "Format", value: format)
                                }
                                if let trackCount = medium.trackCount {
                                    MetadataRow(key: "Track Count", value: "\(trackCount)")
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        } else {
            Text("No release information available")
                .foregroundColor(.secondary)
        }
    }
}

// Helper view for flowing layout of tags and genres
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)
        for (index, line) in result.lines.enumerated() {
            let y = bounds.minY + result.lineOffsets[index]
            var x = bounds.minX
            
            for item in line {
                let position = CGPoint(x: x, y: y)
                subviews[item.index].place(at: position, proposal: .unspecified)
                x += item.size.width + spacing
            }
        }
    }
    
    private struct FlowResult {
        struct Item {
            let index: Int
            let size: CGSize
        }
        
        struct Line: Sequence {
            var items: [Item] = []
            var width: CGFloat = 0
            var height: CGFloat = 0
            
            func makeIterator() -> Array<Item>.Iterator {
                return items.makeIterator()
            }
        }
        
        let lines: [Line]
        let lineOffsets: [CGFloat]
        let size: CGSize
        
        init(in maxWidth: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var lines: [Line] = [Line()]
            var currentLine = 0
            var remainingWidth = maxWidth
            var maxHeight: CGFloat = 0
            var lineOffsets: [CGFloat] = [0]
            
            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(.unspecified)
                
                if size.width > remainingWidth && !lines[currentLine].items.isEmpty {
                    currentLine += 1
                    lines.append(Line())
                    remainingWidth = maxWidth
                    lineOffsets.append(maxHeight)
                }
                
                lines[currentLine].items.append(Item(index: index, size: size))
                lines[currentLine].width += size.width + spacing
                lines[currentLine].height = max(lines[currentLine].height, size.height)
                remainingWidth -= size.width + spacing
                maxHeight = max(maxHeight, lineOffsets[currentLine] + lines[currentLine].height)
            }
            
            self.lines = lines
            self.lineOffsets = lineOffsets
            self.size = CGSize(width: maxWidth, height: maxHeight)
        }
    }
}
