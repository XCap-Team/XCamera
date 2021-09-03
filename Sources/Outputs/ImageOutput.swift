//
//  ImageOutput.swift
//  
//
//  Created by chen on 2021/4/21.
//

import AVFoundation

@available(OSX, deprecated: 10.15)
class ImageOutput: Capturable {
    
    private var _output = AVCaptureStillImageOutput()
    
    var output: AVCaptureOutput { _output }
    
    init?(session: AVCaptureSession) {
        guard session.canAddOutput(_output) else { return nil }
        
        _output.outputSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        session.addOutput(output)
    }
    
    func capture(flipOptions: FlipOptions, _ completionHandler: @escaping CaptureHandler) {
        guard let connection = output.connection(with: .video) else {
            return DispatchQueue.main.async {
                completionHandler(.failure(.noConnection))
            }
        }
        guard !_output.isCapturingStillImage else {
            return DispatchQueue.main.async {
                completionHandler(.failure(.busy))
            }
        }
        
        connection.applyFlipOptions(flipOptions)
        
        _output.captureStillImageAsynchronously(from: connection) { sampleBuffer, error in
            guard let sampleBuffer = sampleBuffer,
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else {
                return DispatchQueue.main.async {
                    if error != nil {
                        completionHandler(.failure(.internalError))
                    } else {
                        completionHandler(.failure(.unknown))
                    }
                }
            }
            
            DispatchQueue.main.async {
                completionHandler(.success(pixelBuffer))
            }
        }
    }
    
}
