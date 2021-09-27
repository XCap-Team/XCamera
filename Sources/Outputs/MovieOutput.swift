//
//  MovieOutput.swift
//  
//
//  Created by chen on 2021/4/21.
//

#if os(macOS)
import AVFoundation

class MovieOutput: NSObject, AVCaptureFileOutputRecordingDelegate, Outputable {
    
    private var _output = AVCaptureMovieFileOutput()
    
    var output: AVCaptureOutput { _output }
    var isRecording: Bool { _output.isRecording }
    var isPaused: Bool { _output.isRecordingPaused }
    
    var didStart: ((URL) -> Void)?
    var didPause: ((URL) -> Void)?
    var didResume: ((URL) -> Void)?
    var didFinish: ((URL, Error?) -> Void)?
    
    // MARK: - Init
    
    init?(session: AVCaptureSession) {
        guard session.canAddOutput(_output) else { return nil }
        
        super.init()
        
        session.addOutput(output)
    }
    
    // MARK: - Recording
    
    /// Returns `false` if there's no video connection or create file URL failed.
    @discardableResult
    func startRecording(flipOptions: FlipOptions) -> Bool {
        guard let connection = output.connection(with: .video),
              let url = URL.tempPathURL()?.appendingPathExtension("mov")
        else { return false }
        connection.applyFlipOptions(flipOptions)
        _output.startRecording(to: url, recordingDelegate: self)
        return true
    }
    
    func pauseRecording() {
        _output.pauseRecording()
    }
    
    func resumeRecording() {
        _output.resumeRecording()
    }
    
    func stopRecording() {
        _output.stopRecording()
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo url: URL, from conn: [AVCaptureConnection]) {
        didStart?(url)
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didPauseRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        didPause?(fileURL)
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didResumeRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        didResume?(fileURL)
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from conn: [AVCaptureConnection], error err: Error?) {
        didFinish?(url, err)
    }
    
}
#endif
