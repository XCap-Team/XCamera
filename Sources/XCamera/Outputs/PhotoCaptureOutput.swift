//
//  PhotoCaptureOutput.swift
//  
//
//  Created by scchn on 2021/9/28.
//

import Foundation
import AVFoundation

#if os(macOS)
import AppKit

public typealias ImgaeCaptureCompletionHandler = (Result<NSImage, CaptureOutputError>) -> Void
#else
import UIKit

public typealias ImgaeCaptureCompletionHandler = (Result<UIImage, CaptureOutputError>) -> Void
#endif

public class PhotoCaptureOutput: CaptureOutput {
    
    private let output: CaptureOutput
    
    public var captureOutput: AVCaptureOutput { output.captureOutput }
    
    public init() {
        #if os(macOS)
        if #available(macOS 10.15, *) {
            output = PhotoOutput()
        } else {
            output = StillImageOutput()
        }
        #else
        output = PhotoOutput()
        #endif
    }
    
    public func capture(_ completionHandler: @escaping CaptureOutputHandler) {
        output.capture(completionHandler)
    }
    
    public func captureImage(_ completionHandler: @escaping ImgaeCaptureCompletionHandler) {
        capture { result in
            do {
                guard let image = Image(cvPixelBuffer: try result.get()) else {
                    completionHandler(.failure(.internalError))
                    return
                }
                completionHandler(.success(image))
            } catch let error as CaptureOutputError {
                completionHandler(.failure(error))
            } catch {}
        }
    }
    
}
