import SwiftUI

struct MusicBrainzReleaseInfoView: View {
    let releaseGroup: MusicBrainzClient.ReleaseGroup?
    let release: MusicBrainzClient.Release?
    let isLoading: Bool
    @State private var listenCount: Int?
    @State private var isLoadingListenCount = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter
    }()
    
    private func formatDate(_ dateString: String?) -> String? {
        guard let dateString = dateString else { return nil }
        
        // MusicBrainz dates are typically in YYYY-MM-DD format
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: dateString) {
            return dateFormatter.string(from: date)
        }
        
        // If the date string doesn't match the expected format, return it as is
        return dateString
    }
    
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
                    if let type = releaseGroup.type {
                        MetadataRow(key: "Type", value: type)
                    }
                }
                
                // Tags (excluding those that are already genres)
                if let tags = releaseGroup.tags,
                   let genres = releaseGroup.genres,
                   !tags.isEmpty {
                    let genreNames = Set(genres.map { $0.name.lowercased() })
                    let uniqueTags = tags.filter { !genreNames.contains($0.name.lowercased()) }
                    
                    if !uniqueTags.isEmpty {
                        Group {
                            Text("Tags")
                                .font(.headline)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(uniqueTags, id: \.name) { tag in
                                    Text(tag.name.lowercased())
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }
                        }
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
                            MetadataRow(key: "Date", value: formatDate(date) ?? date)
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
            .task {
                await fetchListenCount(releaseGroupId: releaseGroup.id)
            }
        } else {
            Text("No release information available")
                .foregroundColor(.secondary)
        }
    }
    
    private func fetchListenCount(releaseGroupId: String) async {
        isLoadingListenCount = true
        defer { isLoadingListenCount = false }
        
        do {
            listenCount = try await ListenBrainzClient.shared.getReleaseGroupListenCount(releaseGroupId: releaseGroupId)
        } catch {
            print("Error fetching listen count: \(error)")
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
