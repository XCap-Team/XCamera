//
//  Camera.swift
//  
//
//  Created by scchn on 2021/9/27.
//

import Foundation
import AVFoundation

public enum CameraError: Error {
    case runtimeError
    case disconnected
    case cancelled
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
    
}

public class Camera {
    
    private let session = AVCaptureSession()
    private let videoInput: AVCaptureDeviceInput
    private var audioInput: AVCaptureDeviceInput?
    
    private var keyValueObservations: [NSKeyValueObservation] = []
    private var notificationObservers: [NSObjectProtocol] = []
    
    private let videoPreviewLayers: NSHashTable<AVCaptureVideoPreviewLayer> = .weakObjects()
    
    public var flipOptions: FlipOptions = .default {
        didSet { didChangeFlipOptions() }
    }
    public var ignoreFlipOptions: Bool = false {
        didSet { didChangeFlipOptions() }
    }
    private var realFlipOptions: FlipOptions? {
        ignoreFlipOptions ? nil : flipOptions
    }
    
    // Device
    private(set)
    public var isValid: Bool = true
    public var videoDevice: AVCaptureDevice { videoInput.device }
    public var audioDevice: AVCaptureDevice? { audioInput?.device }
    
    // Deivce Info
    public var isRunning: Bool { session.isRunning }
    public var name: String { videoDevice.localizedName }
    public var uniqueID: String { videoDevice.uniqueID }
    public var modelID: String { videoDevice.modelID }
    public var preset: AVCaptureSession.Preset {
        get { session.sessionPreset }
        set { session.sessionPreset = newValue }
    }
    
    @available(iOS 14.0, *)
    public var manufacturer: String { videoDevice.manufacturer }
    
    // Format
    public var formats: [AVCaptureDevice.Format] { videoDevice.formats }
    public var activeFormat: AVCaptureDevice.Format { videoDevice.activeFormat }
    
    // Frame Rate Range
    public var frameRateRanges: [AVFrameRateRange] { videoDevice.activeFormat.videoSupportedFrameRateRanges }
    public var activeFrameRateRange: AVFrameRateRange? { videoDevice.activeFrameRateRange }
    
    // Event Handlers
    public var formatUpdateHandler: ((AVCaptureDevice.Format) -> Void)?
    public var frameRateRangeUpdateHandler: ((AVFrameRateRange) -> Void)?
    public var audioDeviceRemoveHandler: (() -> Void)?
    public var didBecomeInvalid: ((CameraError) -> Void)?
    
    public init?(videoDevice: AVCaptureDevice) {
        guard videoDevice.hasMediaType(.video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput)
        else {
            return nil
        }
        
        session.beginConfiguration()
        session.addInput(videoInput)
        session.commitConfiguration()
        
        self.videoInput = videoInput
        
        setupKeyValueObservations()
        setupNotificationObservers()
    }
    
    public convenience init?(uniqueID: String) {
        guard let device = AVCaptureDevice(uniqueID: uniqueID) else {
            return nil
        }
        
        self.init(videoDevice: device)
    }
    
    deinit {
        invalidate(with: nil)
        
        #if DEBUG
        print("XCamera -> deinit")
        #endif
    }
    
    private func setupKeyValueObservations() {
        let formatObservation = videoDevice.observe(
            \.activeFormat,
             options: [.initial, .new]
        ) { [weak self] device, _ in
            guard let self = self else { return }
            self.formatUpdateHandler?(device.activeFormat)
        }
        
        let frameRateRangeObservation = videoDevice.observe(
            \.activeVideoMinFrameDuration,
             options: [.initial, .new]
        ) { [weak self] device, _ in
            guard let self = self, let range = device.activeFrameRateRange else { return }
            self.frameRateRangeUpdateHandler?(range)
        }
        
        keyValueObservations = [formatObservation, frameRateRangeObservation]
    }
    
    private func setupNotificationObservers() {
        let center = NotificationCenter.default
        
        let runtimeErrorObserver = center.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] noti in
            guard let self = self, self.session == noti.object as? AVCaptureSession else { return }
            self.invalidate(with: .runtimeError)
        }
        
        let disconnectionObserver = center.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] noti in
            guard let self = self, let device = noti.object as? AVCaptureDevice else { return }
            
            if device == self.videoDevice {
                self.invalidate(with: .disconnected)
            } else if device == self.audioDevice {
                self.removeAudioDevice()
            }
        }
        
        notificationObservers = [disconnectionObserver, runtimeErrorObserver]
    }
    
    private func didChangeFlipOptions() {
        session.outputs
            .compactMap { $0.connection(with:.video) }
            .forEach { $0.flip(realFlipOptions) }
        
        videoPreviewLayers.allObjects
            .forEach { $0.connection?.flip(realFlipOptions) }
    }
    
    private func validationCheck() {
        if !isValid {
            fatalError("Unavailable camera.")
        }
    }
    
    private func configure(_ configurationHandler: () -> Void) -> Bool {
        do {
            try videoDevice.lockForConfiguration()
            session.beginConfiguration()
            
            configurationHandler()
            
            session.commitConfiguration()
            videoDevice.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }
    
    private func invalidate(with error: CameraError?) {
        guard isValid else { return }

        keyValueObservations.forEach { $0.invalidate() }
        notificationObservers.forEach(NotificationCenter.default.removeObserver(_:))
        
        videoPreviewLayers.allObjects.forEach {
            $0.session = nil
            $0.removeFromSuperlayer()
        }
        videoPreviewLayers.removeAllObjects()
        
        session.beginConfiguration()
        session.inputs.forEach(session.removeInput(_:))
        session.outputs.forEach(session.removeOutput(_:))
        session.commitConfiguration()
        session.stopRunning()
        
        isValid = false
        
        if let error = error {
            didBecomeInvalid?(error)
        }
    }
    
    public func invalidate() {
        invalidate(with: .cancelled)
    }
    
    public func start() {
        validationCheck()
        
        guard !isRunning else {
            return
        }
        
        session.startRunning()
    }
    
    public func stop() {
        guard isRunning else {
            return
        }
        
        session.stopRunning()
    }
    
    public func canSetPreset(_ preset: AVCaptureSession.Preset) -> Bool {
        session.canSetSessionPreset(preset)
    }
    
    // MARK: - Format
    
    @discardableResult
    public func setFormat(_ format: AVCaptureDevice.Format) -> Bool {
        validationCheck()
        
        guard videoDevice.activeFormat != format else {
            return true
        }
        
        return configure {
            videoDevice.activeFormat = format
        }
    }
    
    // MARK: - Frame Rate Range
    
    @discardableResult
    public func setFrameRateRange(_ frameRateRange: AVFrameRateRange) -> Bool {
        validationCheck()
        
        guard videoDevice.activeVideoMinFrameDuration != frameRateRange.minFrameDuration else {
            return true
        }
        
        return configure {
            videoDevice.activeVideoMinFrameDuration = frameRateRange.minFrameDuration
        }
    }
    
    // MARK: - Audio Device
    
    @discardableResult
    public func removeAudioDevice() -> Bool {
        guard let audioInput = audioInput else {
            return false
        }
        
        if removeInput(audioInput) {
            self.audioInput = nil
            audioDeviceRemoveHandler?()
            return true
        }
        return false
    }
    
    @discardableResult
    public func setAudioDevice(_ audioDevice: AVCaptureDevice) -> Bool {
        guard audioDevice.hasMediaType(.audio), removeAudioDevice(),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice)
        else {
            return false
        }
        
        if addInput(audioInput) {
            self.audioInput = audioInput
            return true
        }
        return false
    }
    
    // MARK: - Output
    
    @discardableResult
    public func addOutput(_ output: Output) -> Bool {
        validationCheck()
        
        guard session.canAddOutput(output.captureOutput) else {
            return false
        }
        
        return configure {
            session.addOutput(output.captureOutput)
            
            if let connection = output.captureOutput.connection(with: .video) {
                connection.flip(realFlipOptions)
            }
        }
    }
    
    @discardableResult
    public func removeOutput(_ output: Output) -> Bool {
        guard session.outputs.contains(output.captureOutput) else {
            return false
        }
        
        return configure {
            session.removeOutput(output.captureOutput)
        }
    }
    
    // MARK: - Input
    
    @discardableResult
    public func addInput(_ input: Input) -> Bool {
        validationCheck()
        
        guard session.canAddInput(input.captureInput) else {
            return false
        }
        
        return configure {
            session.addInput(input.captureInput)
        }
    }
    
    @discardableResult
    public func removeInput(_ input: Input) -> Bool {
        guard session.inputs.contains(input.captureInput) else {
            return false
        }
        
        return configure {
            session.removeInput(input.captureInput)
            
            if input.captureInput == videoInput {
                invalidate()
            }
        }
    }
    
    // MARK: - Video Preview Layer
    
    public func createVideoPreviewLayer() -> AVCaptureVideoPreviewLayer {
        validationCheck()
        
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        
        videoPreviewLayer.connection?.flip(realFlipOptions)
        
        videoPreviewLayers.add(videoPreviewLayer)
        
        return videoPreviewLayer
    }
    
    @discardableResult
    public func createVideoPreviewLayer(insertInto superLayer: CALayer, at index: UInt32? = nil) -> AVCaptureVideoPreviewLayer {
        let videoPreviewLayer = createVideoPreviewLayer()
        
        #if os(macOS)
        videoPreviewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        #endif
        
        videoPreviewLayer.frame = superLayer.bounds
        
        if let index = index {
            superLayer.insertSublayer(videoPreviewLayer, at: index)
        } else {
            superLayer.addSublayer(videoPreviewLayer)
        }
        
        return videoPreviewLayer
    }
    
}
