//
//  CVPixelBuffer+Ext.swift
//  
//
//  Created by scchn on 2021/9/29.
//

import Foundation
import CoreMedia

extension CVPixelBuffer {
    
    var size: CGSize {
        CGSize(
            width: CVPixelBufferGetWidth(self),
            height: CVPixelBufferGetHeight(self)
        )
    }
    
}
