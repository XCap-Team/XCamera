//
//  PhotoOutput.swift
//  
//
//  Created by chen on 2021/4/21.
//

import Foundation
import AVFoundation

@available(macOS 10.15, iOS 10.0, *)
class PhotoOutput: NSObject, CaptureOutput {
    
    private let output = AVCapturePhotoOutput()
    private var queuedHandlers: [Int64: CaptureOutputHandler] = [:]
    
    var captureOutput: AVCaptureOutput { output }
    
    override init() {
        super.init()
    }
    
    func capture(_ completionHandler: @escaping CaptureOutputHandler) {
        guard output.connection(with: .video) != nil else {
            return DispatchQueue.main.async {
                completionHandler(.failure(.noVideoConnection))
            }
        }
        
        let format = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        let settings = AVCapturePhotoSettings(format: format)
        queuedHandlers[settings.uniqueID] = completionHandler
        output.capturePhoto(with: settings, delegate: self)
    }
    
}

@available(macOS 10.15, iOS 10.0, *)
extension PhotoOutput: AVCapturePhotoCaptureDelegate {
    
    #if os(iOS)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        guard let completionHandler = queuedHandlers.removeValue(forKey: resolvedSettings.uniqueID) else {
            return
        }
        guard let sampleBuffer = photoSampleBuffer, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return DispatchQueue.main.async {
                completionHandler(.failure(.internalError))
            }
        }
        
        DispatchQueue.main.async {
            completionHandler(.success(pixelBuffer))
        }
    }
    #endif

    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let completionHandler = queuedHandlers.removeValue(forKey: photo.resolvedSettings.uniqueID) else {
            return
        }
        guard let pixBuf = photo.pixelBuffer else {
            return DispatchQueue.main.async {
                completionHandler(.failure(.internalError))
            }
        }
        
        DispatchQueue.main.async {
            completionHandler(.success(pixBuf))
        }
    }
    
}
