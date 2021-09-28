//
//  CaptureOutput.swift
//  
//
//  Created by scchn on 2021/9/27.
//

import Foundation
import AVFoundation

public enum CaptureOutputError: Error {
    case busy
    case noVideoConnection
    case internalError
}

public typealias CaptureOutputHandler = (Result<CVPixelBuffer, CaptureOutputError>) -> Void

public protocol CaptureOutput: Output {
    func capture(_ completionHandler: @escaping CaptureOutputHandler)
}
