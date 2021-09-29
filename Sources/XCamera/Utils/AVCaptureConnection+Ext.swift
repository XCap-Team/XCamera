//
//  AVCaptureConnection+Ext.swift
//  
//
//  Created by scchn on 2021/9/27.
//

import Foundation
import AVFoundation

extension AVCaptureConnection {
    
    func flip(_ flipOptions: FlipOptions?) {
        guard let flipOptions = flipOptions else {
            automaticallyAdjustsVideoMirroring = true
            return
        }
        
        automaticallyAdjustsVideoMirroring = false
        
        if isVideoMirroringSupported && isVideoOrientationSupported {
            if flipOptions == .mirrored {
                isVideoMirrored = true
                videoOrientation = .portrait
            } else if flipOptions == .upsideDown {
                isVideoMirrored = true
                videoOrientation = .portraitUpsideDown
            } else if flipOptions.contains([.mirrored, .upsideDown]) {
                isVideoMirrored = false
                videoOrientation = .portraitUpsideDown
            } else {
                isVideoMirrored = false
                videoOrientation = .portrait
            }
        }
    }

}
