//
//  FourCharCode+Ext.swift
//  
//
//  Created by scchn on 2021/9/30.
//

import Foundation

extension FourCharCode {
    
    var string: String {
        let cString: [CChar] = [
            CChar(self >> 24 & 0xff),
            CChar(self >> 16 & 0xff),
            CChar(self >> 8  & 0xff),
            CChar(self       & 0xff),
            0
        ]
        return String(cString: cString)
    }
    
}
