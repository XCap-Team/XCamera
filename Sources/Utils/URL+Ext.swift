//
//  URL+Ext.swift
//  
//
//  Created by chen on 2021/4/21.
//

import Foundation

extension URL {
    
    static func tempPathURL() -> URL? {
        let directory = NSTemporaryDirectory()
        let fileName = NSUUID().uuidString
        return NSURL.fileURL(withPathComponents: [directory, fileName])
    }
    
}
