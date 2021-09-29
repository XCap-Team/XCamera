//
//  CMSampleBuffer+Ext.swift
//  
//
//  Created by scchn on 2021/9/25.
//

import Foundation
import CoreMedia
import XCamera

extension CMSampleBuffer {
    
    func pixelBuffer(flipOptions: FlipOptions, _ drawingHandler: ((CGRect) -> Void)? = nil) -> CVPixelBuffer? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }
        guard let drawingHandler = drawingHandler else {
            return pixelBuffer
        }
        
        pixelBuffer.applyDrawing(flipOptions: flipOptions, drawingHandler)
        return pixelBuffer
    }
    
}
