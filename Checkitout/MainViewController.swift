//
//  ViewController.swift
//  Checkitout
//
//  Created by 藤井陽介 on 2017/02/22.
//  Copyright © 2017年 touyou. All rights reserved.
//

import UIKit
import AVFoundation

class MainViewController: UIViewController {
    
    var players = [AVAudioPlayer?]()
    var fileNames = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // sample
        fileNames = [
            ""
        ]
        
        setPlayers()
    }
    
    private func setPlayers() {
        
        players = []
        
        for fileName in fileNames {
            let url = Bundle.main.url(forResource: fileName, withExtension: "mp3")
            if let url = url {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    players.append(player)
                } catch {
                    players.append(nil)
                }
            } else {
                players.append(nil)
            }
        }
    }
    
    @IBAction func tapMPCButton(_ sender: UIButton) {
        guard let player = players[sender.tag] else {
            return
        }
        
        player.numberOfLoops = 1
        player.play()
    }
}

