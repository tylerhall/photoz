//
//  main.swift
//  photoz
//
//  Created by Tyler Hall on 8/22/20.
//  Copyright © 2020 Tyler Hall. All rights reserved.
//

import Foundation
import FMDB
import Checksum

let dryRun = false
let noisy = true

try? FileManager.default.removeItem(atPath: "photos.sqlite")
let queue = FMDatabaseQueue(path: "photos.sqlite")

let operationQueue = OperationQueue()
operationQueue.maxConcurrentOperationCount = (ProcessInfo().processorCount * 2)

var importURL: URL!
var libraryURL: URL!

enum DirType: Int {
    case Album
    case YearMonth
    case YearMonthDay
    case Unknown
}

if CommandLine.arguments.count == 4 {
    guard CommandLine.arguments[1] == "import" else {
        print("Invalid arguments")
        exit(EXIT_FAILURE)
    }

    let importDir = CommandLine.arguments[2]
    importURL = URL(fileURLWithPath: importDir)

    let libraryDir = CommandLine.arguments[3]
    libraryURL = URL(fileURLWithPath: libraryDir)

    mergeIntoLibrary()

    exit(EXIT_SUCCESS)
}

if CommandLine.arguments.count == 3 {
    guard CommandLine.arguments[1] == "organize" else {
        print("Invalid arguments")
        exit(EXIT_FAILURE)
    }

    let libraryDir = CommandLine.arguments[2]
    libraryURL = URL(fileURLWithPath: libraryDir)

    queue?.inDatabase({ (db) in
        db.executeStatements("CREATE TABLE IF NOT EXISTS photo_hashes (path TEXT, hash TEXT, dir_type INTEGER);")
    })

    generateAllHashes()
    organizeLibrary()
    cleanupLibrary()

    exit(EXIT_SUCCESS)
}

print("Usage: photoz import /path/to/photos /path/to/library")
print("Usage: photoz organize /path/to/library")
exit(EXIT_FAILURE)
