//
//  AVCaptureConnection+Ext.swift
//  
//
//  Created by chen on 2021/4/21.
//

import AVFoundation

extension AVCaptureConnection {
    
    func applyFlipOptions(_ flipOptions: FlipOptions) {
        guard isVideoMirroringSupported && isVideoOrientationSupported else { return }
                
        if automaticallyAdjustsVideoMirroring {
            automaticallyAdjustsVideoMirroring = false
        }
        
        switch flipOptions {
        case .mirrored:
            isVideoMirrored = true
            videoOrientation = .portrait
        case .upsideDown:
            isVideoMirrored = true
            videoOrientation = .portraitUpsideDown
        case [.mirrored, .upsideDown]:
            isVideoMirrored = false
            videoOrientation = .portraitUpsideDown
        default:
            isVideoMirrored = false
            videoOrientation = .portrait
        }
    }

}
