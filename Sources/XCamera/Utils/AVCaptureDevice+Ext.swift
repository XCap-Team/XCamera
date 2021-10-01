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
    
    /*
     >= macOS 12:
     00000000-0011-0000-AAAA-0000BBBB0000
                        ----     ----
                        pid      vid
     ------------------------------------
     < macOS 12:
     0x14200000AAAABBBB
               --------
               pid vid
     */
    
    var vendorID: Int? {
        if #available(macOS 12, *) {
            let components = self.uniqueID.components(separatedBy: "-")
            guard components.count >= 5 else { return nil }
            return Int(components[components.count - 2], radix: 16)
        } else {
            guard uniqueID.count >= 8 else { return nil }
            let end = uniqueID.index(uniqueID.endIndex, offsetBy: -4)
            let start = uniqueID.index(end, offsetBy: -4)
            return Int(uniqueID[start..<end], radix: 16)
        }
    }
        
    var productID: Int? {
        if #available(macOS 12, *) {
            guard uniqueID.count >= 8 else { return nil }
            let end = uniqueID.index(uniqueID.endIndex, offsetBy: -4)
            let start = uniqueID.index(end, offsetBy: -4)
            return Int(uniqueID[start..<end], radix: 16)
        } else {
            guard uniqueID.count >= 8 else { return nil }
            let end = uniqueID.endIndex
            let start = uniqueID.index(end, offsetBy: -4)
            return Int(uniqueID[start..<end], radix: 16)
        }
    }
    
}

extension AVCaptureDevice.Format {
    
    public var mediaSubTypeName: String {
        if #available(macOS 10.15, *) {
            return formatDescription.mediaSubType.rawValue.string
        } else {
            return CMFormatDescriptionGetMediaSubType(formatDescription).string
        }
    }
    
    public var formatName: String? {
        CMFormatDescriptionGetExtension(
            formatDescription,
            extensionKey: kCMFormatDescriptionExtension_FormatName
        ) as? String
    }
    
    public var dimensions: CGSize {
        let mediaType = CMFormatDescriptionGetMediaType(formatDescription)
        
        guard mediaType == kCMMediaType_Video || mediaType == kCMMediaType_Muxed else {
            return .zero
        }
        
        let dimensions: CMVideoDimensions = {
            if #available(macOS 10.15, *) {
                return formatDescription.dimensions
            } else {
                return CMVideoFormatDescriptionGetDimensions(formatDescription)
            }
        }()
        
        return CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
    }
    
}
