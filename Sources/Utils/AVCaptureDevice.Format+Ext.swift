//
//  AVCaptureDevice.Format+Ext.swift
//  
//
//  Created by chen on 2021/5/10.
//

import AVFoundation

extension AVCaptureDevice.Format {
    
    public var name: String? {
        CMFormatDescriptionGetExtension(
            formatDescription,
            extensionKey: kCMFormatDescriptionExtension_FormatName
        ) as? String
    }
    
    public var dimensions: CGSize {
        let mediaType = CMFormatDescriptionGetMediaType(formatDescription)
        
        guard mediaType == kCMMediaType_Video || mediaType == kCMMediaType_Muxed else { return .zero }
        
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        
        return CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
    }
    
}
