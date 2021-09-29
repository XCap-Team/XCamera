//
//  CVPixelBuffer+Ext.swift
//  
//
//  Created by scchn on 2021/9/28.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import CoreMedia
import XCamera

extension CVPixelBufferLockFlags {
    static let none = CVPixelBufferLockFlags()
}

extension CVPixelBuffer {
    
    func applyDrawing(flipOptions: FlipOptions, _ drawingHandler: (CGRect) -> Void) {
        guard CVPixelBufferLockBaseAddress(self, .none) == kCVReturnSuccess else {
            return
        }
        
        defer {
            CVPixelBufferUnlockBaseAddress(self, .none)
        }
        
        let data = CVPixelBufferGetBaseAddress(self)
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let bitsPerComponent = 8
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = {
            let byteOrderInfo = CGImageByteOrderInfo.order32Little
            let alphaInfo = CGImageAlphaInfo.premultipliedFirst
            return byteOrderInfo.rawValue | alphaInfo.rawValue
        }()
        
        guard let ctx = CGContext(data: data,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo)
        else {
            return
        }
        
        // Push
        #if os(macOS)
        let graphCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphCtx
        #else
        UIGraphicsPushContext(ctx)
        #endif
        
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        
        if flipOptions.contains(.mirrored) {
            ctx.translateBy(x: rect.width, y: 0)
            ctx.scaleBy(x: -1, y: 1)
        }
        
        if flipOptions.contains(.upsideDown) {
            ctx.translateBy(x: 0, y: rect.height)
            ctx.scaleBy(x: 1, y: -1)
        }
        
        drawingHandler(rect)
        
        // Pop
        #if os(macOS)
        NSGraphicsContext.restoreGraphicsState()
        #else
        UIGraphicsPopContext()
        #endif
    }
    
}
