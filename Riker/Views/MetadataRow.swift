import SwiftUI

struct MetadataRow: View {
    let key: String
    let value: String?
    
    var body: some View {
        if let value = value {
            HStack(alignment: .top) {
                Text(key)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .leading)
                Text(value)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
} 
