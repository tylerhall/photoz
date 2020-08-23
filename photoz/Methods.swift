//
//  Methods.swift
//  photoz
//
//  Created by Tyler Hall on 8/22/20.
//  Copyright © 2020 Tyler Hall. All rights reserved.
//

import Foundation
import Checksum

func generateAllHashes() {
    // I prefer to crash if this fails for some reason
    let directories = try! FileManager.default.contentsOfDirectory(at: libraryURL, includingPropertiesForKeys: nil, options: [FileManager.DirectoryEnumerationOptions.skipsHiddenFiles])
    for dirURL in directories {
        print("# Scanning Directory: \(dirURL.path)")

        var dirType: DirType
        if dirURL.isAlbum {
            dirType = .Album
        } else if dirURL.isYearMonthFolder {
            dirType = .YearMonth
        } else if dirURL.isYearMonthDayFolder {
            dirType = .YearMonthDay
        } else {
            continue // I don't want to touch directories that aren't in a format I'm expecting.
        }

        guard let files = try? FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: [FileManager.DirectoryEnumerationOptions.skipsHiddenFiles]) else { continue }

        for fileURL in files {
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir)
            if !exists || isDir.boolValue {
                continue
            }

            if(fileURL.pathExtension.lowercased() == "json") {
                try? FileManager.default.removeItem(at: fileURL)
                continue
            }

            let op = BlockOperation {
                print("## Calculating Hash \(operationQueue.operationCount): \(fileURL.path)")
                if let md5 = fileURL.checksum(algorithm: .md5) {
                    let lib = libraryURL.path
                    let file = fileURL.path
                    let relative = file.replacingOccurrences(of: lib, with: "")

                    queue?.inDatabase({ (db) in
                        do {
                            try db.executeUpdate("INSERT INTO photo_hashes (path, hash, dir_type) VALUES (?, ?, ?)", values: [relative, md5, dirType.rawValue])
                        } catch {
                            fatalError("Could not insert hash for \(fileURL.path)")
                        }
                    })
                }
            }
            operationQueue.addOperation(op)
        }
    }

    operationQueue.waitUntilAllOperationsAreFinished()
}

func organizeLibrary() {
    queue?.inDatabase({ (db) in
        guard let results = try? db.executeQuery("SELECT * FROM photo_hashes WHERE dir_type = ?", values: [DirType.YearMonthDay.rawValue]) else { fatalError() }
        
        while results.next() {
            guard let path = results.string(forColumn: "path") else { fatalError() }
            guard let hash = results.string(forColumn: "hash") else { fatalError() }

            guard let countResults = try? db.executeQuery("SELECT COUNT(*) FROM photo_hashes WHERE hash = ? AND dir_type != ?", values: [hash, DirType.YearMonthDay.rawValue]) else { fatalError() }
            if countResults.next() {
                let count = countResults.int(forColumnIndex: 0)
                if count == 0 {
                    print("### Move \(path)")
                    let originalFileURL = libraryURL.appendingPathComponent(path)
                    moveFileIntoAppropriateYearMonthAlbum(originalFileURL)
                } else {
                    print("### Duplicate \(path)")
                }
            }
            countResults.close()
        }
    })
}

func moveFileIntoAppropriateYearMonthAlbum(_ fileURL: URL) {
    let folderURL = fileURL.deletingLastPathComponent()
    guard folderURL.isYearMonthDayFolder else { return }

    let filename = fileURL.lastPathComponent
    let yearMonth =  String(folderURL.lastPathComponent.prefix(7)) // "YYYY-MM"
    let destDirURL = libraryURL.appendingPathComponent(yearMonth)

    var destURL = destDirURL.appendingPathComponent(filename)
    var numericSuffix = 0
    while(FileManager.default.fileExists(atPath: destURL.path)) {
        numericSuffix += 1

        if let dotIndex = filename.lastIndex(of: ".") {
            var potentialFilename = filename
            potentialFilename.insert(contentsOf: " (\(numericSuffix))", at: dotIndex)
            destURL = destDirURL.appendingPathComponent(potentialFilename)
        } else {
            let potentialFilename = filename + " (\(numericSuffix))"
            destURL = destDirURL.appendingPathComponent(potentialFilename)
        }
    }

    print("###### ==> \(destURL.path)")
    try? FileManager.default.createDirectory(at: destDirURL, withIntermediateDirectories: true, attributes: nil)
    try! FileManager.default.moveItem(at: fileURL, to: destURL) // I prefer to crash if this fails for some reason
}

func cleanupLibrary() {
    queue?.inDatabase({ (db) in
        guard let results = try? db.executeQuery("SELECT * FROM photo_hashes WHERE dir_type = ? OR dir_type = ?", values: [DirType.YearMonthDay.rawValue, DirType.YearMonth.rawValue]) else { fatalError() }
        
        while results.next() {
            guard let path = results.string(forColumn: "path") else { fatalError() }
            guard let hash = results.string(forColumn: "hash") else { fatalError() }

            guard let countResults = try? db.executeQuery("SELECT COUNT(*) FROM photo_hashes WHERE hash = ? AND dir_type = ?", values: [hash, DirType.Album.rawValue]) else { fatalError() }
            if countResults.next() {
                let count = countResults.int(forColumnIndex: 0)
                if count > 0 {
                    let originalFileURL = libraryURL.appendingPathComponent(path)
                    print("### Found date photo in album \(originalFileURL.path)")
                    print("###### DELETING")
                    try? FileManager.default.removeItem(at: originalFileURL)
                }
            }
            countResults.close()
        }
    })
    
    // I prefer to crash if this fails for some reason
    let directories = try! FileManager.default.contentsOfDirectory(at: libraryURL, includingPropertiesForKeys: nil, options: [FileManager.DirectoryEnumerationOptions.skipsHiddenFiles])
    for dirURL in directories {
        if dirURL.isYearMonthDayFolder {
            print("### DELETING year-month-day folder \(dirURL.path)")
            try? FileManager.default.removeItem(at: dirURL)
        }
    }
}

func mergeIntoLibrary() {
    let directories = try! FileManager.default.contentsOfDirectory(at: importURL, includingPropertiesForKeys: nil, options: [FileManager.DirectoryEnumerationOptions.skipsHiddenFiles])
    for dirURL in directories {
        print("# Scanning Import Directory: \(dirURL.path)")
        
        let dirName = dirURL.lastPathComponent
        let dirLibURL = libraryURL.appendingPathComponent(dirName)
        try? FileManager.default.createDirectory(at: dirLibURL, withIntermediateDirectories: true, attributes: nil)

        guard let files = try? FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: [FileManager.DirectoryEnumerationOptions.skipsHiddenFiles]) else { continue }

        for fileURL in files {
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir)
            if !exists || isDir.boolValue {
                continue
            }

            if(fileURL.pathExtension.lowercased() == "json") {
                try? FileManager.default.removeItem(at: fileURL)
                continue
            }
            
            let filename = fileURL.lastPathComponent
            var destURL = dirLibURL.appendingPathComponent(filename)
            var numericSuffix = 0
            while(FileManager.default.fileExists(atPath: destURL.path)) {
                numericSuffix += 1

                if let dotIndex = filename.lastIndex(of: ".") {
                    var potentialFilename = filename
                    potentialFilename.insert(contentsOf: " (\(numericSuffix))", at: dotIndex)
                    destURL = dirLibURL.appendingPathComponent(potentialFilename)
                } else {
                    let potentialFilename = filename + " (\(numericSuffix))"
                    destURL = dirLibURL.appendingPathComponent(potentialFilename)
                }
            }

            try! FileManager.default.moveItem(at: fileURL, to: destURL) // I prefer to crash if this fails for some reason
        }
    }

    operationQueue.waitUntilAllOperationsAreFinished()
}
