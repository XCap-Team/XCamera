//
//  SingleUseVideoWriter.swift
//  
//
//  Created by ViTiny on 2021/9/29.
//

import Foundation
import AVFoundation
import XCamera

extension FlipOptions {
    
    var transform: CGAffineTransform {
        let sx: CGFloat = contains(.mirrored) ? -1 : 1
        let sy: CGFloat = contains(.upsideDown) ? -1 : 1
        return CGAffineTransform.identity.scaledBy(x: sx, y: sy)
    }
    
}

final class SingleUseVideoWriter {
    
    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let videoInputAdaptor: AVAssetWriterInputPixelBufferAdaptor
    private let audioInput: AVAssetWriterInput?
    
    let flipOptions: FlipOptions
    var status: AVAssetWriter.Status { assetWriter.status }
    var transform: CGAffineTransform { videoInput.transform }
    var isReadyForMoreVideoData: Bool { videoInput.isReadyForMoreMediaData }
    var isReadyForMoreAudioData: Bool { audioInput?.isReadyForMoreMediaData ?? false }
    
    init?(outputURL: URL,
          fileType: AVFileType,
          flipOptions: FlipOptions,
          videoInput: AVAssetWriterInput,
          audioInput: AVAssetWriterInput?,
          expectsMediaDataInRealTime: Bool)
    {
        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: fileType) else {
            return nil
        }
        
        // Video Input
        self.videoInput = videoInput
        self.videoInputAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        
        videoInput.expectsMediaDataInRealTime = expectsMediaDataInRealTime
        videoInput.transform = flipOptions.transform
        
        guard assetWriter.canAdd(videoInput) else {
            return nil
        }
        
        assetWriter.add(videoInput)
        
        // Audio Input
        
        if let audioInput = audioInput, assetWriter.canAdd(audioInput) {
            assetWriter.add(audioInput)
            self.audioInput = audioInput
        } else {
            self.audioInput = nil
        }
        
        // Start
        
        assetWriter.startWriting()
        
        self.assetWriter = assetWriter
        self.flipOptions = flipOptions
    }
    
    func setStartTime(at sourceTime: CMTime) {
        assetWriter.startSession(atSourceTime: sourceTime)
    }
    
    // MARK: - Video
    
    func append(videoSampleBuffer: CMSampleBuffer, drawingHandler: ((CGRect) -> Void)?) -> Bool {
        guard videoInput.isReadyForMoreMediaData else {
            return false
        }
        guard let pixelBuffer = videoSampleBuffer.pixelBuffer(flipOptions: flipOptions, drawingHandler) else {
            return false
        }
        
        let timeStamp = CMSampleBufferGetOutputPresentationTimeStamp(videoSampleBuffer)
        return videoInputAdaptor.append(pixelBuffer, withPresentationTime: timeStamp)
    }
    
    // MARK: - Audio
    
    func append(audioSampleBuffer: CMSampleBuffer) -> Bool {
        guard let input = audioInput else {
            return false
        }
        
        return input.append(audioSampleBuffer)
    }
    
    // MARK: - Finish
    
    func cancel() {
        assetWriter.cancelWriting()
    }
    
    func finish(_ completionHandler: @escaping (URL?) -> Void) {
        assetWriter.finishWriting { [weak self] in
            guard let self = self else {
                return
            }
            
            if self.assetWriter.status == .completed {
                completionHandler(self.assetWriter.outputURL)
            } else {
                completionHandler(nil)
            }
        }
    }
    
}
