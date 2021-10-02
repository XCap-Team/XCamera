//
//  AVCaptureDevice.Format+Ext.swift
//  
//
//  Created by scchn on 2021/10/1.
//

import Foundation
import AVFoundation

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
