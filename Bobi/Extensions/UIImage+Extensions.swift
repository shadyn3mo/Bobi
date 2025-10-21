import UIKit

extension UIImage {
    func convertToGrayscale() -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return self }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let newCGImage = context.makeImage() else { return self }
        
        return UIImage(cgImage: newCGImage, scale: self.scale, orientation: self.imageOrientation)
    }
    
    func forceRemoveAlpha() -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return self }
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let newCGImage = context.makeImage() else { return self }
        
        return UIImage(cgImage: newCGImage, scale: self.scale, orientation: self.imageOrientation)
    }
    
    func optimizedForReceipt() -> UIImage {
        return convertToGrayscale()
    }
}