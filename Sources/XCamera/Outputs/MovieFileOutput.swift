//
//  MovieFileOutput.swift
//  
//
//  Created by chen on 2021/4/21.
//

import Foundation
import AVFoundation

public class MovieFileOutput: NSObject, Output {
    
    public static func temporaryFileURL() -> URL {
        URL.temporaryFileURL(pathExtension: "mov")
    }
    
    private var output = AVCaptureMovieFileOutput()
    
    public var captureOutput: AVCaptureOutput { output }
    
    public var isRecording: Bool { output.isRecording }
    #if os(macOS)
    public var isPaused: Bool { output.isRecordingPaused }
    #endif
    
    public var didStart: ((URL) -> Void)?
    #if os(macOS)
    public var didPause: ((URL) -> Void)?
    public var didResume: ((URL) -> Void)?
    #endif
    public var didFinish: ((URL, Error?) -> Void)?
    
    // MARK: - Init
    
    public override init() {
        super.init()
    }
    
    // MARK: - Recording
    
    /// Returns `false` if there's no video connection or create file URL failed.
    @discardableResult
    public func startRecording(outputURL: URL) -> Bool {
        output.startRecording(to: outputURL, recordingDelegate: self)
        return true
    }
    
    #if os(macOS)
    public func pauseRecording() {
        output.pauseRecording()
    }
    
    public func resumeRecording() {
        output.resumeRecording()
    }
    #endif
    
    public func stopRecording() {
        output.stopRecording()
    }
    
}

extension MovieFileOutput: AVCaptureFileOutputRecordingDelegate {
    
    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo url: URL, from conn: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            self.didStart?(url)
        }
    }
    
    #if os(macOS)
    public func fileOutput(_ output: AVCaptureFileOutput, didPauseRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            self.didPause?(fileURL)
        }
    }
    
    public func fileOutput(_ output: AVCaptureFileOutput, didResumeRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            self.didResume?(fileURL)
        }
    }
    #endif
    
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from conn: [AVCaptureConnection], error err: Error?) {
        DispatchQueue.main.async {
            self.didFinish?(url, err)
        }
    }
    
}
