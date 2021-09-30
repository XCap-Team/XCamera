//
//  ViewController.swift
//  XCameraDemo
//
//  Created by scchn on 2021/9/29.
//

import Cocoa

import XCamera
import AVFoundation

extension Camera {
    static let `default`: Camera = {
        guard let device = AVCaptureDevice.default(for: .video) else {
            fatalError("Init camera failed.")
        }
        return Camera(videoDevice: device)!
    }()
}

class ViewController: NSViewController {

    @IBOutlet weak var previewView: NSView!
    @IBOutlet weak var recordButton: NSButton!
    @IBOutlet weak var formatPopUpButton: NSPopUpButton!
    
    private var camera = Camera.default
    private let photoOutput = PhotoCaptureOutput()
    private let movieFileOutput = MovieFileOutput()
    private let videoDataOutput = VideoDataOutput(queue: .main)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        AVCaptureDevice.requestAccess(for: .video) { ok in
            guard ok else {
                fatalError("Check camera permission")
            }
            
            DispatchQueue.main.async {
                self.setupCamera()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func setupUI() {
        let formatNames = camera.formats.enumerated().map { index, format -> String in
            let dimensions = format.dimensions
            let dimensionsDescription = "\(Int(dimensions.width)) x \(Int(dimensions.height))"
            return "\(index + 1). \(format.name ?? "Unknown") (\(dimensionsDescription))"
        }
        formatPopUpButton.removeAllItems()
        formatPopUpButton.addItems(withTitles: formatNames)
        updateFormatPopUpButton()
        
        let layer = CALayer()
        layer.backgroundColor = .black
        previewView.layer = layer
        previewView.wantsLayer = true
        camera.createVideoPreviewLayer(into: layer)
    }
    
    private func setupCamera() {
        movieFileOutput.didStart = { [weak self] _ in
            self?.recordButton.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)
            self?.recordButton.isEnabled = true
        }
        
        movieFileOutput.didFinish = { [weak self] outputURL, _ in
            self?.recordButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
            self?.recordButton.isEnabled = true
            self?.openSavePanel(with: .quickTimeMovie, { url in
                guard let url = url else {
                    try? FileManager.default.removeItem(at: outputURL)
                    return
                }
                
                try? FileManager.default.moveItem(at: outputURL, to: url)
            })
        }
        
        videoDataOutput.dataOutputHandler = { _ in
            print("[\(Date())] Received sameple buffer")
        }
        
        camera.formatUpdateHandler = { [weak self] format in
            self?.updateFormatPopUpButton()
        }
        
        camera.didBecomeInvalid = { [weak self] error in
            self?.showAlert(title: "Bye : \(error)") {
                NSApp.terminate(nil)
            }
        }
        
        camera.addOutput(photoOutput)
        camera.addOutput(movieFileOutput)
        camera.start()
    }
    
    private func updateFormatPopUpButton() {
        guard let index = camera.formats.firstIndex(of: camera.activeFormat),
              (0..<formatPopUpButton.numberOfItems).contains(index)
        else {
            return
        }
        formatPopUpButton.selectItem(at: index)
    }
    
    // MARK: -
    
    private func showAlert(title: String, _ handler: (() -> Void)? = nil) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = ""
        alert.beginSheetModal(for: view.window!) { _ in
            handler?()
        }
    }
    
    private func openSavePanel(with type: UTType, _ completionHandler: @escaping (URL?) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [type]
        savePanel.beginSheetModal(for: view.window!) { response in
            guard response == .OK, let url = savePanel.url else {
                return completionHandler(nil)
            }
            completionHandler(url)
        }
    }
    
    // MARK: -

    @IBAction func captureButtonAction(_ sender: Any) {
        photoOutput.captureImage { result in
            guard let image = try? result.get(), let data = image.tiffRepresentation else {
                self.showAlert(title: "Capture failed")
                return
            }
            
            self.openSavePanel(with: .tiff) { url in
                guard let url = url else {
                    return
                }
                try? data.write(to: url)
            }
        }
    }
    
    @IBAction func recordButtonAction(_ sender: NSButton) {
        if movieFileOutput.isRecording {
            movieFileOutput.stopRecording()
        } else {
            let outputURL = MovieFileOutput.temporaryFileURL()
            movieFileOutput.startRecording(outputURL: outputURL)
        }
        
        recordButton.isEnabled = false
    }
    
    @IBAction func formatPopUpButtonAction(_ sender: NSPopUpButton) {
        let format = camera.formats[sender.indexOfSelectedItem]
        camera.setFormat(format)
    }
    
    @IBAction func videoDataOutputCheckbox(_ sender: NSButton) {
        if sender.state == .on {
            camera.addOutput(videoDataOutput)
        } else {
            camera.removeOutput(videoDataOutput)
        }
    }
    
}
