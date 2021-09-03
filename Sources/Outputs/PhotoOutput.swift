//
//  PhotoOutput.swift
//  
//
//  Created by chen on 2021/4/21.
//

import AVFoundation

private let formatKey = kCVPixelBufferPixelFormatTypeKey as String

@available(OSX 10.15, *)
class PhotoOutput: NSObject, AVCapturePhotoCaptureDelegate, Capturable {
    
    private let _output = AVCapturePhotoOutput()
    private let photoSettings = AVCapturePhotoSettings(format: [formatKey: kCVPixelFormatType_32BGRA])
    private var queuedHandlers: [Int64: CaptureHandler] = [:]
    
    var output: AVCaptureOutput { _output }
    
    init?(session: AVCaptureSession) {
        guard session.canAddOutput(_output) else { return nil }
        
        super.init()
        
        session.addOutput(output)
    }
    
    func capture(flipOptions: FlipOptions, _ completionHandler: @escaping CaptureHandler) {
        guard let conn = output.connection(with: .video) else {
            return DispatchQueue.main.async {
                completionHandler(.failure(.noConnection))
            }
        }
        
        let settings = AVCapturePhotoSettings(from: photoSettings)
        
        queuedHandlers[settings.uniqueID] = completionHandler
        
        conn.applyFlipOptions(flipOptions)
        
        _output.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let id = photo.resolvedSettings.uniqueID
        
        guard let completionHandler = queuedHandlers.removeValue(forKey: id) else { return }
        
        guard let pixBuf = photo.pixelBuffer else {
            return DispatchQueue.main.async {
                if error != nil {
                    completionHandler(.failure(.internalError))
                } else {
                    completionHandler(.failure(.unknown))
                }
            }
        }
        
        DispatchQueue.main.async {
            completionHandler(.success(pixBuf))
        }
    }
    
}
