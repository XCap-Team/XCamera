//
//  FrameOutput.swift
//  
//
//  Created by chen on 2021/4/21.
//

import AVFoundation

class FrameOutput: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, Outputable {
    
    private let _output = AVCaptureVideoDataOutput()
    
    var output: AVCaptureOutput { _output }
    
    var frameHandler: ((CMSampleBuffer) -> Void)?
    
    init?(session: AVCaptureSession) {
        guard session.canAddOutput(_output) else { return nil }
        
        super.init()
        
        _output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        _output.setSampleBufferDelegate(self, queue: .main)
        
        session.addOutput(output)
    }
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameHandler?(sampleBuffer)
    }
    
}
