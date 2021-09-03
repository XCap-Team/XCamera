//
//  Capturable.swift
//  
//
//  Created by chen on 2021/4/21.
//

import AVFoundation

public enum CaptureError: Error {
    case noConnection
    case busy
    case internalError
    case unknown
}

public typealias CaptureHandler = (Result<CVPixelBuffer, CaptureError>) -> Void

protocol Capturable: Outputable {
    
    func capture(flipOptions: FlipOptions, _ completionHandler: @escaping CaptureHandler)
    
}
