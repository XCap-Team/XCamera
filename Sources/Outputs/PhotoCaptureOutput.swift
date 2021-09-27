//
//  PhotoCaptureOutput.swift
//  
//
//  Created by scchn on 2021/9/28.
//

import Foundation
import AVFoundation

public class PhotoCaptureOutput: CaptureOutput {
    
    private let output: CaptureOutput
    
    public var captureOutput: AVCaptureOutput { output.captureOutput }
    
    public init() {
        if #available(macOS 10.15, iOS 10.0, *) {
            output = PhotoOutput()
        } else {
            output = StillImageOutput()
        }
    }
    
    public func capture(_ completionHandler: @escaping CaptureOutputHandler) {
        output.capture(completionHandler)
    }
    
}
