//
//  Input.swift
//  
//
//  Created by scchn on 2021/9/27.
//

import Foundation
import AVFoundation

public protocol Input {
    var captureInput: AVCaptureInput { get }
}
