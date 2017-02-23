//
//  FileReader.swift
//  Filer
//
//  Created by Takuma Yoshida on 2015/07/13.
//  Copyright (c) 2015年 yoavlt. All rights reserved.
//

import Foundation
import UIKit

open class FileReader {
    open let file: File
    public init(file: File) {
        self.file = file
    }
    open func read() -> String {
        return readString()
    }
    open func readString() -> String {
        return (try! NSString(contentsOfFile: file.path, encoding: String.Encoding.utf8.rawValue)) as String
    }
    open func readData() -> Data? {
        return Filer.withDir(file.directory) { _, manager in
            return manager.contents(atPath: self.file.path)
        }
    }
    open func readImage() -> UIImage? {
        return UIImage(contentsOfFile: file.path)
    }
}
