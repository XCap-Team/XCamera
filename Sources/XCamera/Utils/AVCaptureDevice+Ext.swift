//
//  AVCaptureDevice+Ext.swift
//  
//
//  Created by scchn on 2021/9/27.
//

import Foundation
import AVFoundation

extension AVCaptureDevice {
    
    public var activeFrameRateRange: AVFrameRateRange? {
        activeFormat.videoSupportedFrameRateRanges.first {
            CMTimeCompare(activeVideoMinFrameDuration, $0.minFrameDuration) == 0
        }
    }
    
}

extension AVCaptureDevice.Format {
    
    public var name: String? {
        CMFormatDescriptionGetExtension(
            formatDescription,
            extensionKey: kCMFormatDescriptionExtension_FormatName
        ) as? String
    }
    
    public var dimensions: CGSize {
        let mediaType = CMFormatDescriptionGetMediaType(formatDescription)
        
        if mediaType == kCMMediaType_Video || mediaType == kCMMediaType_Muxed {
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            return CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
        }
        
        return .zero
    }
    
}
