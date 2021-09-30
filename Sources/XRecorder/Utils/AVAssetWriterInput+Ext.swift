//
//  AVAssetWriterInput+Ext.swift
//  
//
//  Created by scchn on 2021/9/27.
//

import Foundation
import AVFoundation

extension AVAssetWriterInput {
    
    convenience init(videoSettings: Recorder.VideoSettings) {
        var outputSettings: [String: Any]
        var sourceFormatHint: CMFormatDescription?
        
        switch videoSettings {
        case let .auto(codec, formatHint):
            outputSettings = [AVVideoCodecKey: codec]
            sourceFormatHint = formatHint
            
        case let .manual(codec, dimensions):
            outputSettings = [
                AVVideoCodecKey: codec,
                AVVideoWidthKey: Int(dimensions.width),
                AVVideoHeightKey: Int(dimensions.height),
            ]
        }
        
        self.init(
            mediaType: .video,
            outputSettings: outputSettings,
            sourceFormatHint: sourceFormatHint
        )
    }
    
    convenience init(audioSettings: Recorder.AudioSettings) {
        var outputSettings: [String: Any]
        var sourceFormatHint: CMFormatDescription?
        
        switch audioSettings {
        case .auto(let formatID, let hint):
            outputSettings = [
                AVFormatIDKey: formatID,
            ]
            sourceFormatHint = hint
            
        case .manual(let formatID, let sampleRate, let numberOfChannels, let channelLayout):
            outputSettings = [
                AVFormatIDKey: formatID,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: numberOfChannels,
            ]
            if let channelLayout = channelLayout {
                outputSettings[AVChannelLayoutKey] = channelLayout
            }
        }
        
        self.init(
            mediaType: .audio,
            outputSettings: outputSettings,
            sourceFormatHint: sourceFormatHint
        )
    }
    
}
