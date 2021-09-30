//
//  File.swift
//  
//
//  Created by scchn on 2021/9/29.
//

import Foundation
import AVFoundation
import XCamera

extension Recorder {
    
    public enum Status {
        case ready
        case waitingForFirstMediaData
        case writing
        case finishing
    }
    
    public enum FileType {
        case mov
        case mp4
        
        var avFileType: AVFileType { self == .mov ? .mov : .mp4 }
        
    }
    
    public enum VideoSettings {
        case auto(AVVideoCodecType, CMFormatDescription)
        case manual(AVVideoCodecType, CGSize)
    }

    public enum AudioSettings {
        case auto(AudioFormatID, CMFormatDescription)
        
        /**
         1. Format ID
         2. Sample Rate
         3. Number of Channels
         4. Channel Layout (If the number of channel specifies a channel count greater than 2, the settings must also specify a value for channel layout)
         */
        case manual(AudioFormatID, Float, Int, Data?)
    }
    
}

public class Recorder {
    
    private var videoWriter: SingleUseVideoWriter?
    
    private(set)
    public var status: Status = .ready
    public var isReadyForMoreVideoData: Bool { videoWriter?.isReadyForMoreVideoData ?? false }
    public var isReadyForMoreAudioData: Bool { videoWriter?.isReadyForMoreAudioData ?? false }
    public var flipOptions: FlipOptions? { getCurrentFlipOptions() }
    
    public init() {
        
    }
    
    public func setup(outputURL: URL,
                      fileType: FileType,
                      flipOptions: FlipOptions, // Flips input frames but not graphics context.
                      videoSettings: VideoSettings,
                      audioSettings: AudioSettings?,
                      realTime expectsMediaDataInRealTime: Bool = true) -> Bool
    {
        cancel()
        
        let videoInput = AVAssetWriterInput(videoSettings: videoSettings)
        let audioInput = { () -> AVAssetWriterInput? in
            guard let settings = audioSettings else {
                return nil
            }
            
            return AVAssetWriterInput(audioSettings: settings)
        }()
        
        guard let writer = SingleUseVideoWriter(outputURL: outputURL,
                                                fileType: fileType.avFileType,
                                                flipOptions: flipOptions,
                                                videoInput: videoInput,
                                                audioInput: audioInput,
                                                expectsMediaDataInRealTime: expectsMediaDataInRealTime)
        else {
            return false
        }
        
        videoWriter = writer
        status = .waitingForFirstMediaData
        return true
    }
    
    
    private func getCurrentFlipOptions() -> FlipOptions? {
        guard let transform = videoWriter?.transform else {
            return nil
        }
        
        return FlipOptions(
            (transform.a != 1 ? [.mirrored] : []) +
            (transform.d != 1 ? [.upsideDown] : [])
        )
    }
    
    private func setStartTimeIfNeeded(_ time: CMTime) {
        guard let writer = videoWriter, status == .waitingForFirstMediaData else {
            return
        }
        
        writer.setStartTime(at: time)
        status = .writing
    }
    
    private func setStartTimeIfNeeded(with sampleBuffer: CMSampleBuffer) {
        guard let writer = videoWriter, status == .waitingForFirstMediaData else {
            return
        }
        
        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        writer.setStartTime(at: timeStamp)
        status = .writing
    }
    
    // MARK: - Video
    
    @discardableResult
    public func append(frame videoSampleBuffer: CMSampleBuffer, drawingHandler: ((CGRect) -> Void)? = nil) -> Bool {
        guard let writer = videoWriter, status != .finishing else {
            return false
        }
        
        setStartTimeIfNeeded(with: videoSampleBuffer)
        return writer.append(videoSampleBuffer: videoSampleBuffer, drawingHandler: drawingHandler)
    }
    
    // MARK: - Audio
    
    @discardableResult
    public func append(audio audioSampleBuffer: CMSampleBuffer) -> Bool {
        guard let writer = videoWriter, status != .finishing else {
            return false
        }
        
        setStartTimeIfNeeded(with: audioSampleBuffer)
        return writer.append(audioSampleBuffer: audioSampleBuffer)
    }
    
    // MARK: - Finish / Cancel
    
    public func cancel() {
        guard let writer = videoWriter else {
            return
        }
        
        writer.cancel()
        videoWriter = nil
        status = .ready
    }
    
    public func finish(_ completionHandler: @escaping (URL?) -> Void) {
        guard let writer = videoWriter, status != .finishing else {
            DispatchQueue.main.async {
                completionHandler(nil)
            }
            return
        }
        
        status = .finishing
        
        writer.finish { [weak self] outputURL in
            DispatchQueue.main.async {
                self?.videoWriter = nil
                self?.status = .ready
                completionHandler(outputURL)
            }
        }
    }
    
}
