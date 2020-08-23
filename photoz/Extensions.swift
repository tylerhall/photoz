//
//  Extensions.swift
//  photoz
//
//  Created by Tyler Hall on 7/29/20.
//  Copyright © 2020 Tyler Hall. All rights reserved.
//

import Foundation

extension URL {
    var isAlbum: Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir)
        guard exists && isDir.boolValue else { return false }
        
        let lastComponent = self.lastPathComponent
        return lastComponent.range(of: #"^[0-9]{4}-[0-9]{2}\s+.*$"#, options: .regularExpression) != nil
    }

    var isYearMonthFolder: Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir)
        guard exists && isDir.boolValue else { return false }

        let lastComponent = self.lastPathComponent
        return lastComponent.range(of: #"^[0-9]{4}-[0-9]{2}$"#, options: .regularExpression) != nil
    }

    var isYearMonthDayFolder: Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir)
        guard exists && isDir.boolValue else { return false }

        let lastComponent = self.lastPathComponent
        return lastComponent.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}"#, options: .regularExpression) != nil
    }
}
