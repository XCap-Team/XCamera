//
//  Image Conversion.swift
//  
//
//  Created by scchn on 2021/9/29.
//

import Foundation

#if os(macOS)
import AppKit

typealias Image = NSImage
#else
import UIKit

typealias Image = UIImage
#endif

extension Image {
    
    convenience init?(cvPixelBuffer: CVPixelBuffer) {
        let ciContext = CIContext()
        let ciImage = CIImage(cvPixelBuffer: cvPixelBuffer)
        let rect = CGRect(origin: .zero, size: cvPixelBuffer.size)
        
        guard let cgImage = ciContext.createCGImage(ciImage, from: rect) else {
            return nil
        }
        
        #if os(macOS)
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        
        self.init(cgImage: cgImage, size: size)
        #else
        self.init(cgImage: cgImage)
        #endif
    }
    
}
