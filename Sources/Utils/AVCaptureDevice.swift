//
//  AVCaptureDevice+Ext.swift
//  
//
//  Created by chen on 2021/4/21.
//

import AVFoundation

extension AVCaptureDevice {
    
    public var activeFrameRateRange: AVFrameRateRange? {
        activeFormat.videoSupportedFrameRateRanges.first {
            CMTimeCompare(activeVideoMinFrameDuration, $0.minFrameDuration) == 0
        }
    }
    
}
