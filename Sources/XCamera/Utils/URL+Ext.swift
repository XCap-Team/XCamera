//
//  URL+Ext.swift
//  
//
//  Created by scchn on 2021/9/27.
//

import Foundation

extension URL {
    
    static func temporaryFileURL(pathExtension: String) -> URL {
        let directory = NSTemporaryDirectory()
        let fileName = NSUUID().uuidString.appending(pathExtension)
        return NSURL.fileURL(withPathComponents: [directory, fileName])!
    }
    
}
