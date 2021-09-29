//
//  AudioDataOutput.swift
//  
//
//  Created by scchn on 2021/9/27.
//

import Foundation
import AVFoundation

public class AudioDataOutput: NSObject, Output {
    
    private let output = AVCaptureAudioDataOutput()
    
    public var captureOutput: AVCaptureOutput { output }
    
    public var dataOutputHandler: ((CMSampleBuffer) -> Void)?
    
    public init(queue: DispatchQueue, discardsLateFrames: Bool = true) {
        super.init()
        
        #if os(macOS)
        output.audioSettings = nil
        #endif
        
        output.setSampleBufferDelegate(self, queue: queue)
    }
    
}

extension AudioDataOutput: AVCaptureAudioDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        dataOutputHandler?(sampleBuffer)
    }
    
}
