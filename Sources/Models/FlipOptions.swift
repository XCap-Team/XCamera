//
//  FlipOptions.swift
//  
//
//  Created by scchn on 2021/9/27.
//

import Foundation

public struct FlipOptions: OptionSet {
    
    public var rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let `default`  = FlipOptions()
    public static let mirrored   = FlipOptions(rawValue: 1 << 0)
    public static let upsideDown = FlipOptions(rawValue: 1 << 1)
    
}
