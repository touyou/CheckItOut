//
//  FileWriter.swift
//  Filer
//
//  Created by Takuma Yoshida on 2015/07/13.
//  Copyright (c) 2015年 yoavlt. All rights reserved.
//

import Foundation
import UIKit

public enum ImageFormat {
    case png
    case jpeg(CGFloat)
}

open class FileWriter {
    open let file: File
    public init(file: File) {
        self.file = file
    }

    open func write(_ body: String) -> Bool {
        return writeString(body)
    }

    open func append(_ body: String) -> Bool {
        return appendString(body)
    }

    open func writeString(_ body: String) -> Bool {
        do {
            try body.write(toFile: file.path, atomically: true, encoding: String.Encoding.utf8)
            return true
        } catch _ {
            return false
        }
    }

    open func appendString(_ body: String) -> Bool {
        if let data = body.data(using: String.Encoding.utf8) {
            return appendData(data)
        }
        return false
    }

    open func writeData(_ data: Data) -> Bool {
        return ((try? data.write(to: URL(fileURLWithPath: file.path), options: [.atomic])) != nil)
    }

    open func appendData(_ data: Data) -> Bool {
        return withHandler(file.path) { handle in
            handle.seekToEndOfFile()
            handle.write(data)
        }
    }

    open func withHandler(_ path: String, f: (FileHandle) -> ()) -> Bool {
        if let handler = FileHandle(forWritingAtPath: path) {
            f(handler)
            handler.closeFile()
            return true
        }
        return false
    }

    open func writeImage(_ image: UIImage, format: ImageFormat) -> Bool {
        let data = imageToData(image, format: format)
        return writeData(data)
    }

    fileprivate func imageToData(_ image: UIImage, format: ImageFormat) -> Data {
        switch format {
        case .png:
            return UIImagePNGRepresentation(image)!
        case .jpeg(let quality):
            return UIImageJPEGRepresentation(image, quality)!
        }
    }
}
