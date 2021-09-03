//
//  Camera.swift
//  
//
//  Created by chen on 2021/4/21.
//

import Foundation
import AVFoundation

fileprivate func createCaptureOutput(session: AVCaptureSession) -> Capturable? {
    if #available(OSX 10.15, *) { return PhotoOutput(session: session) }
    else                        { return ImageOutput(session: session) }
}

extension Notification.Name {
    static let _flipOptionsWereChanged = Notification.Name("com.scchn.XCamera._flipOptionsWereChanged")
}

public enum CameraError: Error {
    case notVideoDevice
    case invalidDevice
    case createCaptureInputFailed
    case createMovieOutputFailed
}

public protocol CameraDelegate: AnyObject {
    func cameraWasDisconnected(_ camera: Camera)
    
//    func camera(_ camera: Camera, didOutput frame: CMSampleBuffer)
    
    func camera(_ camera: Camera, formatDidChange format: AVCaptureDevice.Format)
    func camera(_ camera: Camera, frameRateRangeDidChange range: AVFrameRateRange)
    func camera(_ camera: Camera, recordingStateDidChange state: Camera.RecordingState)
}

extension Camera {
    
    public static var videoDevices: [AVCaptureDevice] {
        if #available(OSX 10.15, *) {
            let discoverySession1 = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
                mediaType: .video,
                position: .unspecified
            )
            let discoverySession2 = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.externalUnknown],
                mediaType: .muxed,
                position: .unspecified
            )
            return discoverySession1.devices + discoverySession2.devices
        } else {
            return AVCaptureDevice.devices(for: .video)
        }
    }
    
    public enum RecordingState {
        case began(URL)
        case paused(URL)
        case resumed(URL)
        case finished(URL, Error?)
    }
    
}

public class Camera {
    
    private let session: AVCaptureSession = AVCaptureSession()
    private let deviceInput: AVCaptureDeviceInput
    private let captureOutput: Capturable
    private let movieOutput: MovieOutput
    private var frameOutput: FrameOutput?
    
    private var notificationObservers: [NSObjectProtocol] = []
    private var keyValueObservations: [NSKeyValueObservation] = []
    private var retainedLayers = NSHashTable<AVCaptureVideoPreviewLayer>(options: [.weakMemory])
    
    weak
    public var delegate: CameraDelegate?
    
    public var device: AVCaptureDevice  { deviceInput.device }
    public var preset: AVCaptureSession.Preset { session.sessionPreset }
    
    private(set)
    public var isValid = true
    public var isRunning: Bool { session.isRunning }
    
    public var name: String { device.localizedName }
    public var uniqueID: String { device.uniqueID }
    public var manufacturer: String { device.manufacturer }
    public var modelID: String { device.modelID }
    
    // Flip
    public var flipOptions: FlipOptions = .default {
        didSet { NotificationCenter.default.post(name: ._flipOptionsWereChanged, object: self) }
    }
    
    // Frame
    public var isFrameOutputEnabled: Bool { frameOutput != nil }
    /// Main Queue。
    public var frameOutputHandler: ((CMSampleBuffer) -> Void)?
    
    // Format
    public var formats: [AVCaptureDevice.Format] { device.formats }
    public var activeFormat: AVCaptureDevice.Format { device.activeFormat }
    public var dimensions: CGSize { activeFormat.dimensions }
    
    // Frame-Rate Range
    public var frameRateRanges: [AVFrameRateRange] { device.activeFormat.videoSupportedFrameRateRanges }
    public var activeFrameRateRange: AVFrameRateRange? { device.activeFrameRateRange }
    
    // Recording
    public var isRecording: Bool { movieOutput.isRecording }
    public var isRecordingPaused: Bool { movieOutput.isPaused }
    
    public init(device: AVCaptureDevice, preset: AVCaptureSession.Preset = .high) throws {
        guard device.hasMediaType(.video) else {
            throw CameraError.notVideoDevice
        }
        
        // Add capture output
        if let output = createCaptureOutput(session: session) {
            captureOutput = output
        } else {
            throw CameraError.createCaptureInputFailed
        }
        
        // Add movie output
        if let output = MovieOutput(session: session) {
            movieOutput = output
        } else {
            throw CameraError.createMovieOutputFailed
        }
        
        // Create device input
        do {
            deviceInput = try .init(device: device)
        } catch {
            throw CameraError.invalidDevice
        }
        
        // Check if the input is available for the session
        guard session.canAddInput(deviceInput) else {
            throw CameraError.invalidDevice
        }
        
        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
        }
        if !device.supportsSessionPreset(session.sessionPreset) {
            session.sessionPreset = .high
        }
        session.addInput(deviceInput)
        
        setupObservers()
        setupMovieOutput()
    }
    
    deinit {
        invalidate()
        print(#function, self)
    }
    
    private func setupObservers() {
        let nc = NotificationCenter.default
        
        notificationObservers += [
            nc.addObserver(forName: .AVCaptureDeviceWasDisconnected, object: nil, queue: .main) { [weak self] noti in
                guard let self = self, self.device == noti.object as? AVCaptureDevice else { return }
                self.invalidate()
            }
        ]
        
        keyValueObservations += [
            device.observe(\.activeFormat, options: [.initial, .new]) { [weak self] device, _ in
                guard let self = self else { return }
                self.delegate?.camera(self, formatDidChange: device.activeFormat)
            },
            device.observe(\.activeVideoMinFrameDuration, options: [.initial, .new]) { [weak self] device, _ in
                guard let self = self, let range = self.activeFrameRateRange else { return }
                self.delegate?.camera(self, frameRateRangeDidChange: range)
            }
        ]
    }
    
    private func setupMovieOutput() {
        movieOutput.didStart = { [weak self] fileURL in
            guard let self = self else { return }
            self.delegate?.camera(self, recordingStateDidChange: .began(fileURL))
        }
        
        movieOutput.didPause = { [weak self] fileURL in
            guard let self = self else { return }
            self.delegate?.camera(self, recordingStateDidChange: .resumed(fileURL))
        }
        
        movieOutput.didResume = { [weak self] fileURL in
            guard let self = self else { return }
            self.delegate?.camera(self, recordingStateDidChange: .resumed(fileURL))
        }
        
        movieOutput.didFinish = { [weak self] fileURL, error in
            guard let self = self else { return }
            self.delegate?.camera(self, recordingStateDidChange: .finished(fileURL, error))
        }
    }
    
    private func invalidate() {
        guard isValid else { return }
        
        notificationObservers.forEach(NotificationCenter.default.removeObserver(_:))
        
        keyValueObservations.forEach { $0.invalidate() }
        
        session.beginConfiguration()
        retainedLayers.allObjects.forEach {
            $0.session = nil
            $0.removeFromSuperlayer()
        }
        retainedLayers.removeAllObjects()
        session.inputs.forEach(session.removeInput(_:))
        session.outputs.forEach(session.removeOutput(_:))
        session.commitConfiguration()
        
        session.stopRunning()
        
        isValid = false
        
        delegate?.cameraWasDisconnected(self)
    }
    
    public func startRunning() {
        session.startRunning()
    }
    
    public func stopRunning() {
        session.stopRunning()
    }
    
    @discardableResult
    public func disableFrameOutput() -> Bool {
        guard let output = frameOutput else { return true }
        do {
            try device.lockForConfiguration()
            session.removeOutput(output.output)
            frameOutput = nil
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }
    
    @discardableResult
    public func enableFrameOutput() -> Bool {
        guard !isFrameOutputEnabled else { return true }
        guard (try? device.lockForConfiguration()) != nil else { return false }
        
        defer { device.unlockForConfiguration() }
        
        guard let output = FrameOutput(session: session) else { return false }
        
        output.frameHandler = { [weak self] in
            guard let self = self, self.isFrameOutputEnabled else { return }
            self.frameOutputHandler?($0)
        }
        frameOutput = output
        
        return true
    }
    
    @discardableResult
    public func setFormat(_ format: AVCaptureDevice.Format) -> Bool {
        do {
            try device.lockForConfiguration()
            device.activeFormat = format
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }
    
    @discardableResult
    public func setFrameRateRange(_ frameRateRange: AVFrameRateRange) -> Bool {
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = frameRateRange.minFrameDuration
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }
    
    @discardableResult
    public func setPreset(_ preset: AVCaptureSession.Preset) -> Bool {
        guard session.canSetSessionPreset(preset) else { return false }
        session.sessionPreset = preset
        return true
    }
    
    public func capture(_ completionHandler: @escaping CaptureHandler) {
        captureOutput.capture(flipOptions: flipOptions, completionHandler)
    }
    
    public func startRecording() -> Bool {
        movieOutput.startRecording(flipOptions: flipOptions)
    }
    
    public func pauseRecording() {
        movieOutput.pauseRecording()
    }
    
    public func resumeRecording() {
        movieOutput.resumeRecording()
    }
    
    public func stopRecording() {
        movieOutput.stopRecording()
    }
    
    public func createPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        
        layer.connection?.applyFlipOptions(flipOptions)
        
        notificationObservers += [
            NotificationCenter.default.addObserver(
                forName: ._flipOptionsWereChanged,
                object: self,
                queue: .main
            ) { [weak layer] noti in
                guard let layer = layer, let camera = noti.object as? Camera else { return }
                layer.connection?.applyFlipOptions(camera.flipOptions)
            }
        ]
        
        retainedLayers.add(layer)
        
        return layer
    }
    
}

extension Camera {
    
    public var inputs: [AVCaptureInput] {
        session.inputs.filter { $0 != deviceInput }
    }
    public var outputs: [AVCaptureOutput] {
        session.outputs.filter { $0 != captureOutput.output && $0 != movieOutput.output }
    }
    
    @discardableResult
    public func addInput(_ input: AVCaptureInput) -> Bool {
        guard session.canAddInput(input) else { return false }
        session.addInput(input)
        return true
    }
    
    public func removeInput(_ input: AVCaptureInput) {
        session.removeInput(input)
    }
    
    @discardableResult
    public func addOutput(_ output: AVCaptureOutput) -> Bool {
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)
        return true
    }
    
    public func removeOutput(_ output: AVCaptureOutput) {
        session.removeOutput(output)
    }
    
}
