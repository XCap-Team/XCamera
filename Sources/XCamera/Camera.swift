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

open class Camera {
    
    #if DEBUG
    public static var showDeinitLog = true
    #endif
    
    private let session = AVCaptureSession()
    private let videoInput: AVCaptureDeviceInput
    private var audioInput: AVCaptureDeviceInput?
    
    private var keyValueObservations: [NSKeyValueObservation] = []
    private var notificationObservers: [NSObjectProtocol] = []
    
    private let videoPreviewLayers: NSHashTable<AVCaptureVideoPreviewLayer> = .weakObjects()
    
    // MARK: - Deivce Info
    
    open var videoDevice: AVCaptureDevice { videoInput.device }
    open var audioDevice: AVCaptureDevice? { audioInput?.device }
    open var preset: AVCaptureSession.Preset {
        get { session.sessionPreset }
        set { session.sessionPreset = newValue }
    }
    
    private(set)
    open var isValid: Bool = true
    open var isRunning: Bool { session.isRunning }
    open var name: String { videoDevice.localizedName }
    open var uniqueID: String { videoDevice.uniqueID }
    open var modelID: String { videoDevice.modelID }
    
    @available(iOS 14.0, *)
    open var manufacturer: String { videoDevice.manufacturer }
    
    // MARK: - Format
    
    open var formats: [AVCaptureDevice.Format] { videoDevice.formats }
    open var activeFormat: AVCaptureDevice.Format { videoDevice.activeFormat }
    
    // MARK: - Frame-Rate Range
    
    open var frameRates: [AVFrameRateRange] { videoDevice.activeFormat.videoSupportedFrameRateRanges }
    open var activeFrameRate: AVFrameRateRange? { videoDevice.activeFrameRateRange }
    
    // MARK: - Flip Options
    
    open var flipOptions: FlipOptions = .default {
        didSet { didChangeFlipOptions() }
    }
    open var ignoreFlipOptions: Bool = false {
        didSet { didChangeFlipOptions() }
    }
    private var realFlipOptions: FlipOptions? {
        ignoreFlipOptions ? nil : flipOptions
    }
    
    // MARK: - Event Handlers
    
    open var formatUpdateHandler: ((AVCaptureDevice.Format) -> Void)?
    open var frameRateUpdateHandler: ((AVFrameRateRange) -> Void)?
    open var audioInputRemovalHandler: (() -> Void)?
    open var didBecomeInvalid: ((CameraError) -> Void)?
    
    // MARK: - Init
    
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
        if Camera.showDeinitLog {
            print("[XCamera.Camera] \(name) -> Released")
        }
        #endif
    }
    
    private func setupKeyValueObservations() {
        let formatObservation = videoDevice.observe(
            \.activeFormat,
             options: [.initial, .new]
        ) { [weak self] device, _ in
            self?.formatUpdateHandler?(device.activeFormat)
        }
        
        let frameRateObservation = videoDevice.observe(
            \.activeVideoMinFrameDuration,
             options: [.initial, .new]
        ) { [weak self] device, _ in
            guard let range = device.activeFrameRateRange else { return }
            self?.frameRateUpdateHandler?(range)
        }
        
        keyValueObservations = [formatObservation, frameRateObservation]
    }
    
    private func setupNotificationObservers() {
        let center = NotificationCenter.default
        
        let runtimeErrorObserver = center.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] noti in
            guard let self = self, self.session == noti.object as? AVCaptureSession else {
                return
            }
            self.invalidate(with: .runtimeError)
        }
        
        let disconnectionObserver = center.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] noti in
            guard let self = self, let device = noti.object as? AVCaptureDevice else {
                return
            }
            if device == self.videoDevice {
                self.invalidate(with: .disconnected)
            } else if device == self.audioDevice {
                self.removeAudioInput()
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
    
    // MARK: - Utils
    
    private func assertValid() {
        assert(isValid, "Unavailable camera.")
    }
    
    private func configure(_ configurationHandler: () -> Void, errorHandler: ((Error) -> Void)? = nil) -> Bool {
        do {
            try videoDevice.lockForConfiguration()
            session.beginConfiguration()
            
            configurationHandler()
            
            session.commitConfiguration()
            videoDevice.unlockForConfiguration()
            return true
        } catch {
            errorHandler?(error)
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
    
    // MARK: - Session
    
    open func start() {
        assertValid()
        
        guard !isRunning else {
            return
        }
        
        session.startRunning()
    }
    
    open func stop() {
        guard isRunning else {
            return
        }
        
        session.stopRunning()
    }
    
    open func canSetPreset(_ preset: AVCaptureSession.Preset) -> Bool {
        session.canSetSessionPreset(preset)
    }
    
    open func invalidate() {
        invalidate(with: .cancelled)
    }
    
    // MARK: - Video Device Settings
    
    @discardableResult
    open func setFormat(_ format: AVCaptureDevice.Format) -> Bool {
        assertValid()
        
        guard videoDevice.activeFormat != format else {
            return true
        }
        
        return configure {
            videoDevice.activeFormat = format
        }
    }
    
    @discardableResult
    open func setFrameRate(_ frameRateRange: AVFrameRateRange) -> Bool {
        assertValid()
        
        guard videoDevice.activeFrameRateRange != frameRateRange else {
            return true
        }
        
        return configure {
            videoDevice.activeVideoMinFrameDuration = frameRateRange.minFrameDuration
        }
    }
    
    // MARK: - Audio Device
    
    @discardableResult
    open func removeAudioInput() -> Bool {
        guard let audioInput = audioInput else {
            return false
        }
        
        if removeInput(audioInput) {
            self.audioInput = nil
            audioInputRemovalHandler?()
            return true
        }
        return false
    }
    
    @discardableResult
    open func setAudioInput(device audioDevice: AVCaptureDevice) -> Bool {
        guard audioDevice.hasMediaType(.audio), removeAudioInput(),
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
    open func addOutput(_ output: Output) -> Bool {
        assertValid()
        
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
    open func removeOutput(_ output: Output) -> Bool {
        guard session.outputs.contains(output.captureOutput) else {
            return false
        }
        
        return configure {
            session.removeOutput(output.captureOutput)
        }
    }
    
    // MARK: - Input
    
    @discardableResult
    open func addInput(_ input: Input) -> Bool {
        assertValid()
        
        guard session.canAddInput(input.captureInput) else {
            return false
        }
        
        return configure {
            session.addInput(input.captureInput)
        }
    }
    
    @discardableResult
    open func removeInput(_ input: Input) -> Bool {
        guard session.inputs.contains(input.captureInput) else {
            return false
        }
        
        return configure {
            session.removeInput(input.captureInput)
        }
    }
    
    // MARK: - Video Preview Layer
    
    open func createVideoPreviewLayer() -> AVCaptureVideoPreviewLayer {
        assertValid()
        
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        
        videoPreviewLayer.connection?.flip(realFlipOptions)
        
        videoPreviewLayers.add(videoPreviewLayer)
        
        return videoPreviewLayer
    }
    
    @discardableResult
    open func createVideoPreviewLayer(into superLayer: CALayer, at index: UInt32? = nil) -> AVCaptureVideoPreviewLayer {
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
