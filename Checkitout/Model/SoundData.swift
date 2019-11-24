//
//  SoundData.swift
//  Checkitout
//
//  Created by 藤井陽介 on 2017/02/25.
//  Copyright © 2017年 touyou. All rights reserved.
//

import Foundation
import RealmSwift

class SoundData: Object {
    static let realm = try! Realm()
    
    @objc dynamic private var id = 0
    @objc dynamic var isBundle: Bool = false
    @objc dynamic var urlStr: String = ""
    @objc dynamic var displayName: String = ""
    @objc dynamic var padNum: Int = -1
    var url: URL {
        get {
            return isBundle ? Bundle.main.url(forResource: urlStr, withExtension: "wav")! : URL(string: urlStr)!
        }
    }
    
    override static func primaryKey() -> String? {
        return "urlStr"
    }
    
    override static func ignoredProperties() -> [String] {
        return ["url"]
    }
    
    static func create() -> SoundData {
        let sound = SoundData()
        sound.id = lastId()
        return sound
    }
    
    static func loadAll() -> [SoundData] {
        let sounds = realm.objects(SoundData.self).sorted(byKeyPath: "id", ascending: true)
        var ret = [SoundData]()
        for sound in sounds {
            ret.append(sound)
        }
        return ret
    }
    
    static func lastId() -> Int {
        if let sound = realm.objects(SoundData.self).sorted(byKeyPath: "id", ascending: true).last {
            return sound.id + 1
        } else {
            return 1
        }
    }
    
    func save(_ completion: (()->())? = nil) {
        try! SoundData.realm.write {
            SoundData.realm.add(self)
            completion?()
        }
    }
    
    func update(_ method: (() -> Void)) {
        try! SoundData.realm.write {
            method()
        }
    }

    func delete(_ completion: (()->())? = nil) {
        try! SoundData.realm.write {
            SoundData.realm.delete(self)
            completion?()
        }
    }

    static func fetch(_ url: URL, isBundle: Bool) -> SoundData? {
        let str = url.absoluteString
        let fileName = str.components(separatedBy: "/").last
        let noun = fileName?.components(separatedBy: ".").first
        if let data = realm.object(ofType: self, forPrimaryKey: (isBundle ? noun : str) as AnyObject) {
            return data
        }
        return nil
    }
    
    static func assignDefault(_ str: String) -> SoundData? {
        if let data = realm.object(ofType: self, forPrimaryKey: str as AnyObject) {
            return data
        }
        return nil
    }
}
