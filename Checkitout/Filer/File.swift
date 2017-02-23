//
//  File.swift
//  Filer
//
//  Created by Takuma Yoshida on 2015/07/22.
//  Copyright (c) 2015年 yoavlt. All rights reserved.
//

import Foundation
import UIKit

public enum StoreDirectory {
    case home
    case temp
    case document
    case cache
    case inbox
    case library
    case searchDirectory(FileManager.SearchPathDirectory)

    public func path() -> String {
        switch self {
        case .home:
            return NSHomeDirectory()
        case .temp:
            return NSTemporaryDirectory()
        case .document:
            return StoreDirectory.searchDirectory(.documentDirectory).path()
        case .cache:
            return StoreDirectory.searchDirectory(.cachesDirectory).path()
        case .library:
            return StoreDirectory.searchDirectory(.libraryDirectory).path()
        case .inbox:
            return "\(StoreDirectory.library.path())/Inbox"
        case .searchDirectory(let searchPathDirectory):
            return NSSearchPathForDirectoriesInDomains(searchPathDirectory, .userDomainMask, true)[0] 
        }
    }

    static public func from(_ string: String) -> StoreDirectory? {
        return StoreDirectory.paths()[string]
    }
    
    static public func paths() -> [String : StoreDirectory] {
        return [
            "/" : .home,
            "/tmp": .temp,
            "/Documents": .document,
            "/Caches": .cache,
            "/Library": .library,
            "/Library/Inbox": .inbox
        ]
    }
}

open class File : CustomStringConvertible, Equatable {
    fileprivate let writePath: String
    open let directory: StoreDirectory
    open let fileName: String
    open var dirName: String?

    open var dirPath: String {
        if let dirComp = dirName {
            if dirComp.isEmpty {
                return writePath
            }
            return "\(writePath)/\(dirComp)"
        } else {
            return writePath
        }
    }

    open var path: String {
        get {
            return "\(dirPath)/\(fileName)"
        }
    }

    open var relativePath: String {
        get {
            if let dir = dirName {
                return "\(dir)/\(fileName)"
            } else {
                return fileName
            }
        }
    }

    open var isExists: Bool {
        get {
            return Filer.exists(directory, path: relativePath)
        }
    }
    
    open var isDirectory: Bool{
        get{
            return Filer.isDirectory(directory, path: relativePath)
        }
    }

    open var url: URL {
        get {
            return URL(fileURLWithPath: self.path)
        }
    }
    
    open var ext: String? {
        get {
            return fileName.characters.split(whereSeparator: { $0 == "." }).map { String($0) }.last
        }
    }

    open var description: String {
        get {
            return "File \(self.path)"
        }
    }

    public init(directory: StoreDirectory, dirName: String?, fileName: String) {
        self.directory = directory
        if dirName != nil {
            self.dirName = File.toDirName(dirName!)
        }
        self.fileName = fileName
        self.writePath = directory.path()
    }

    public convenience init(directory: StoreDirectory, path: String) {
        if path.isEmpty {
            self.init(directory: StoreDirectory.document, dirName: nil, fileName: "")
        } else {
            let (dirName, fileName) = File.parsePath(path)
            self.init(directory: directory, dirName: dirName, fileName: fileName)
        }
    }

    public convenience init(directory: StoreDirectory, fileName: String) {
        self.init(directory: directory, dirName: nil, fileName: fileName)
    }

    public convenience init(fileName: String) {
        self.init(directory: StoreDirectory.document, dirName: nil, fileName: fileName)
    }

    public convenience init(url: URL) {
        let (dir, dirName, fileName) = File.parsePath(url.absoluteString)!
        self.init(directory: dir, dirName: dirName, fileName: fileName)
    }

    open func delete() -> Bool {
        return Filer.rm(directory, path: self.fileName)
    }
    
    open func copyTo(_ toPath: String) -> Bool {
        return Filer.cp(directory, srcPath: relativePath, toPath: toPath)
    }
    
    open func moveTo(_ toPath: String) -> Bool {
        return Filer.mv(directory, srcPath: relativePath, toPath: toPath)
    }
    
    open func read() -> String {
        return FileReader(file: self).read()
    }

    open func readData() -> Data? {
        return FileReader(file: self).readData() as Data?
    }

    open func readImage() -> UIImage? {
        return FileReader(file: self).readImage()
    }

    open func write(_ body: String) -> Bool {
        return FileWriter(file: self).write(body)
    }

    open func writeData(_ data: Data) -> Bool {
        return FileWriter(file: self).writeData(data)
    }
    
    open func writeImage(_ image: UIImage, format: ImageFormat) -> Bool {
        return FileWriter(file: self).writeImage(image, format: format)
    }

    open func append(_ body: String) -> Bool {
        if self.isExists == false {
            return FileWriter(file: self).write(body)
        }
        return FileWriter(file: self).append(body)
    }

    open func appendData(_ data: Data) -> Bool {
        if self.isExists == false {
            return FileWriter(file: self).writeData(data)
        }
        return FileWriter(file: self).appendData(data)
    }
    
    // MARK: static methods
    open static func parsePath(_ string: String) -> (String?, String) {
        let comps = string.components(separatedBy: "/")
        let fileName = comps.last!
        let dirName = comps.dropLast().joined(separator: "/")
        if dirName.isEmpty {
            return (nil, fileName)
        }
        return (dirName, fileName)
    }

    open static func parsePath(_ absoluteString: String) -> (StoreDirectory, String?, String)? {
        let comps = absoluteString.components(separatedBy: NSHomeDirectory())
        let names = Array(StoreDirectory.paths().keys)
        if let homeRelativePath = comps.last {
            let firstMathes = names.filter { homeRelativePath.range(of: $0) != nil }.first
            if let name = firstMathes {
                if let dir = StoreDirectory.from(name) {
                    let path = homeRelativePath.replacingOccurrences(of: name, with: "", options: .literal, range: nil)
                    let (dirName, fileName) = parsePath(path)
                    return (dir, dirName, fileName)
                }
            }
        }
        return nil
    }

    open static func toDirName(_ dirName: String) -> String {
        switch Array(dirName.characters).last {
        case .some("/"):
            return String(dirName.characters.dropLast())
        default:
            return dirName
        }
    }
}

public func ==(lhs: File, rhs: File) -> Bool {
    return lhs.path == rhs.path
}

infix operator ->> { associativity left }

public func ->>(lhs: String, rhs: File) -> Bool {
    return rhs.append(lhs)
}

public func ->>(lhs: Data, rhs: File) -> Bool {
    return rhs.appendData(lhs)
}

infix operator --> { associativity left }

public func -->(lhs: String, rhs: File) -> Bool {
    return rhs.write(lhs)
}

public func -->(lhs: Data, rhs: File) -> Bool {
    return rhs.writeData(lhs)
}
