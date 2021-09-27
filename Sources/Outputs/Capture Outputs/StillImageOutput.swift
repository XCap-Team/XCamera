//
//  StillImageOutput.swift
//  
//
//  Created by chen on 2021/4/21.
//

import Foundation
import AVFoundation

@available(macOS, deprecated: 10.15)
@available(iOS, deprecated: 10.0)
class StillImageOutput: CaptureOutput {
    
    private var output = AVCaptureStillImageOutput()
    
    var captureOutput: AVCaptureOutput { output }
    
    init() {
        output.outputSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
    }
    
    func capture(_ completionHandler: @escaping CaptureOutputHandler) {
        guard let connection = output.connection(with: .video) else {
            return DispatchQueue.main.async {
                completionHandler(.failure(.noVideoConnection))
            }
        }
        guard !output.isCapturingStillImage else {
            return DispatchQueue.main.async {
                completionHandler(.failure(.busy))
            }
        }
        
        output.captureStillImageAsynchronously(from: connection) { sampleBuffer, error in
            guard let sampleBuffer = sampleBuffer,
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else {
                return DispatchQueue.main.async {
                    completionHandler(.failure(.internalError))
                }
            }
            
            DispatchQueue.main.async {
                completionHandler(.success(pixelBuffer))
            }
        }
    }
    
}
