//
//  VideoDataOutput.swift
//  
//
//  Created by chen on 2021/4/21.
//

import Foundation
import AVFoundation

public class VideoDataOutput: NSObject, Output {
    
    private let output = AVCaptureVideoDataOutput()
    
    public var captureOutput: AVCaptureOutput { output }
    
    public var dataOutputHandler: ((CMSampleBuffer) -> Void)?
    
    public init(queue: DispatchQueue, discardsLateFrames: Bool = true) {
        super.init()
        
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = discardsLateFrames
        output.setSampleBufferDelegate(self, queue: queue)
    }
    
}

extension VideoDataOutput: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        dataOutputHandler?(sampleBuffer)
    }
    
}
