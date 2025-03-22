import UIKit

extension UIImage {
    func analyzeFirstRowColors() -> (isConsistent: Bool, dominantColor: UIColor?) {
        guard let cgImage = self.cgImage else { return (false, nil) }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let provider = cgImage.dataProvider,
              let data = provider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return (false, nil)
        }
        
        // Check bitmap info to determine byte order
        let alphaInfo = cgImage.alphaInfo
        let byteOrder = cgImage.bitmapInfo.rawValue & CGBitmapInfo.byteOrderMask.rawValue
        
        // Function to get correct color components based on byte order
        func getColorComponents(from offset: Int) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
            if byteOrder == CGBitmapInfo.byteOrder32Little.rawValue {
                return (bytes[offset + 2], bytes[offset + 1], bytes[offset], bytes[offset + 3])
            } else {
                return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
            }
        }
        
        let firstComponents = getColorComponents(from: 0)
        let firstPixel = (
            red: CGFloat(firstComponents.red) / 255.0,
            green: CGFloat(firstComponents.green) / 255.0,
            blue: CGFloat(firstComponents.blue) / 255.0,
            alpha: CGFloat(firstComponents.alpha) / 255.0
        )
        
        for i in 0..<min(20, width) {
            let offset = i * 4
            let components = getColorComponents(from: offset)
        }
        
        var isConsistent = true
        let threshold: CGFloat = 0.05
        
        for x in 0..<width {
            let offset = x * 4
            let components = getColorComponents(from: offset)
            let red = CGFloat(components.red) / 255.0
            let green = CGFloat(components.green) / 255.0
            let blue = CGFloat(components.blue) / 255.0
            
            if abs(red - firstPixel.red) > threshold ||
               abs(green - firstPixel.green) > threshold ||
               abs(blue - firstPixel.blue) > threshold {
                isConsistent = false
                break
            }
        }
        
        let dominantColor = UIColor(
            red: firstPixel.red,
            green: firstPixel.green,
            blue: firstPixel.blue,
            alpha: firstPixel.alpha
        )
        
        return (isConsistent, dominantColor)
    }
} 