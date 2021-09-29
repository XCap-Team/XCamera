//
//  NSImage+Ext.swift
//  XCameraDemo
//
//  Created by scchn on 2021/9/29.
//

import AppKit

extension NSImage {
    
    convenience init?(cvPixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: cvPixelBuffer)
        let ciContext = CIContext()
        let size = CGSize(
            width: CVPixelBufferGetWidth(cvPixelBuffer),
            height: CVPixelBufferGetHeight(cvPixelBuffer)
        )
        let rect = CGRect(origin: .zero, size: size)
        
        guard let cgImage = ciContext.createCGImage(ciImage, from: rect) else {
            return nil
        }
        
        self.init(cgImage: cgImage, size: size)
    }
    
}
