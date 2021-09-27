//
//  Camera.swift
//  
//
//  Created by chen on 2021/4/21.
//

import Foundation
import AVFoundation

fileprivate func createCaptureOutput(session: AVCaptureSession) -> Capturable? {
    if #available(macOS 10.15, iOS 10.0, *) {
        return PhotoOutput(session: session)
    } else {
        return ImageOutput(session: session)
    }
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
    
    func camera(_ camera: Camera, formatDidChange format: AVCaptureDevice.Format)
    func camera(_ camera: Camera, frameRateRangeDidChange range: AVFrameRateRange)
    
    #if os(macOS)
    func camera(_ camera: Camera, recordingStateDidChange state: Camera.RecordingState)
    #endif
}

extension Camera {
    
    #if os(macOS)
    public static var videoDevices: [AVCaptureDevice] {
        if #available(macOS 10.15, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
                mediaType: .video,
                position: .unspecified
            )
            return discoverySession.devices
        } else {
            return AVCaptureDevice.devices(for: .video)
        }
    }
    #endif
    
    #if os(macOS)
    public enum RecordingState {
        case began(URL)
        case paused(URL)
        case resumed(URL)
        case finished(URL, Error?)
    }
    #endif
    
}

public class Camera {
    
    private let session: AVCaptureSession = AVCaptureSession()
    private let deviceInput: AVCaptureDeviceInput
    private let captureOutput: Capturable
    private var frameOutput: FrameOutput?
    #if os(macOS)
    private let movieOutput: MovieOutput
    #endif
    
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
    @available(iOS 14.0, *)
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
    #if os(macOS)
    public var isRecording: Bool { movieOutput.isRecording }
    public var isRecordingPaused: Bool { movieOutput.isPaused }
    #endif
    
    public init(device: AVCaptureDevice, preset: AVCaptureSession.Preset? = nil) throws {
        guard device.hasMediaType(.video) else { throw CameraError.notVideoDevice }
        
        session.beginConfiguration()
        
        if let preset = preset, device.supportsSessionPreset(preset) {
            session.sessionPreset = preset
        }
        
        // Create device input
        guard let deviceInput = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(deviceInput)
        else { throw CameraError.invalidDevice }
        session.addInput(deviceInput)
        self.deviceInput = deviceInput
        
        // Add capture output
        guard let output = createCaptureOutput(session: session) else { throw CameraError.createCaptureInputFailed }
        captureOutput = output
        
        // Add movie output
        #if os(macOS)
        guard let output = MovieOutput(session: session) else { throw CameraError.createMovieOutputFailed }
        movieOutput = output
        setupMovieOutput()
        #endif
        
        session.commitConfiguration()
        
        setupObservers()
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
    
    #if os(macOS)
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
    #endif
    
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
    
    #if os(macOS)
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
    #endif
    
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
        #if os(macOS)
        session.outputs.filter { $0 != captureOutput.output && $0 != frameOutput?.output && $0 != movieOutput.output }
        #else
        session.outputs.filter { $0 != captureOutput.output && $0 != frameOutput?.output }
        #endif
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
