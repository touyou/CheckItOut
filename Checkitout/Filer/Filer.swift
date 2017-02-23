//
//  Filer.swift
//  Filer
//
//  Created by Takuma Yoshida on 2015/07/13.
//  Copyright (c) 2015年 yoavlt. All rights reserved.
//

import Foundation

open class Filer {
    // MARK: static methods
    open static func withDir <T> (_ directory: StoreDirectory, f: (String, FileManager) -> T) -> T {
        let writePath = directory.path()
        let fileManager = FileManager.default
        return f(writePath, fileManager)
    }

    open static func mkdir(_ directory: StoreDirectory, dirName: String) -> Bool {
        return withDir(directory) { path, manager in
            let path = "\(path)/\(dirName)"
            do {
                try manager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                return true
            } catch _ {
                return false
            }
        }
    }

    open static func touch(_ directory: StoreDirectory, path: String) -> Bool {
        return FileWriter(file: File(directory: directory, path: path)).write("")
    }

    open static func rm(_ directory: StoreDirectory, path: String) -> Bool {
        return withDir(directory) { dirPath, manager in
            let filePath = "\(dirPath)/\(path)"
            do {
                try manager.removeItem(atPath: filePath)
                return true
            } catch _ {
                return false
            }
        }
    }

    open static func mv(_ directory: StoreDirectory, srcPath: String, toPath: String) -> Bool {
        return withDir(directory) { path, manager in
            let from = "\(path)/\(srcPath)"
            let to = "\(path)/\(toPath)"
            do {
                try manager.moveItem(atPath: from, toPath: to)
                return true
            } catch _ {
                return false
            }
        }
    }

    open static func rmdir(_ directory: StoreDirectory, dirName: String) -> Bool {
        return rm(directory, path: dirName)
    }

    open static func cp(_ directory: StoreDirectory, srcPath: String, toPath: String) -> Bool {
        return withDir(directory) { path, manager in
            let from = "\(path)/\(srcPath)"
            let to = "\(path)/\(toPath)"
            do {
                try manager.copyItem(atPath: from, toPath: to)
                return true
            } catch _ {
                return false
            }
        }
    }

    open static func test(_ directory: StoreDirectory, path: String) -> Bool {
        return withDir(directory) { dirPath, manager in
            let path = "\(dirPath)/\(path)"
            return manager.fileExists(atPath: path)
        }
    }

    open static func exists(_ directory: StoreDirectory, path: String) -> Bool {
        return test(directory, path: path)
    }

    open static func ls(_ directory: StoreDirectory, dir: String = "") -> [File]? {
        return withDir(directory) { dirPath, manager in
            let path = "\(dirPath)/\(dir)"
            return (try? manager.contentsOfDirectory(atPath: path))?.map { "\(dir)/\($0)" }
                .map { path in File(directory: directory, path: path) }
        }
    }

    open static func cat(_ directory: StoreDirectory, path: String) -> String {
        return File(directory: directory, path: path).read()
    }

    open static func du(_ directory: StoreDirectory, path: String) -> UInt64 {
        return withDir(directory) { dirPath, manager in
            let path = "\(dirPath)/\(path)"
            if let item: NSDictionary = try! manager.attributesOfItem(atPath: path) as NSDictionary? {
                return item.fileSize()
            }
            return 0
        }
    }
    
    open static func isDirectory(_ directory: StoreDirectory, path: String) -> Bool {
        return withDir(directory) { dirPath, manager in
            let path = "\(dirPath)/\(path)"
            var isDir : ObjCBool = false
            if(manager.fileExists(atPath: path,isDirectory: &isDir)){
                return isDir.boolValue
            }else{
                return false
            }
        }
    }
    
    open static func grep(_ directory: StoreDirectory, dir: String = "", contains: [String]) -> [File]? {
        return ls(directory, dir: dir)?.filter {
            var isContain = false
            for str in contains {
                let body = FileReader(file: $0).read()
                if body.contains(str) {
                    isContain = true
                }
            }
            return isContain
        }
    }

    open static func tree(_ directory: StoreDirectory, dir: String = "") -> [File]? {
        let currentFiles = ls(directory, dir: dir)?.filter { $0.isDirectory == false }
        let directories = ls(directory, dir: dir)?.filter { $0.isDirectory }
        if let dirs = directories {
            var files = dirs.map { (file: File) in Filer.tree(file.directory, dir: file.fileName) }
            files.append(currentFiles)
            return files.flatMap { $0 }.flatMap { $0 }
        }
        return currentFiles
    }
    
    open static func df() -> Double {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.libraryDirectory, FileManager.SearchPathDomainMask.userDomainMask, true);
        do {
            let dict  = try FileManager.default.attributesOfFileSystem(forPath: paths.last!)
            let mb: Double = 1024 * 1024
            if let freeSize = (dict[FileAttributeKey.systemFreeSize]! as AnyObject).doubleValue {
                return  freeSize / mb
            } else {
                return -1
            }
        } catch {
            return -1
        }
    }
    
}
