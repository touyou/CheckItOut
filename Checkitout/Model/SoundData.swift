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
    
    dynamic private var id = 0
    dynamic var urlStr: String = ""
    dynamic var displayName: String = ""
    dynamic var padNum: Int = -1
    var url: URL {
        get {
            return URL(string: urlStr)!
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
    
    func save() {
        try! SoundData.realm.write {
            SoundData.realm.add(self)
        }
    }
    
    func update(_ method: (() -> Void)) {
        try! SoundData.realm.write {
            method()
        }
    }
    
    static func fetch(_ str: String) -> SoundData? {
        if let data = realm.object(ofType: self, forPrimaryKey: str as AnyObject) {
            return data
        }
        return nil
    }
}
