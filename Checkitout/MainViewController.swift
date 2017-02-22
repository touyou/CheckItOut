//
//  ViewController.swift
//  Checkitout
//
//  Created by 藤井陽介 on 2017/02/22.
//  Copyright © 2017年 touyou. All rights reserved.
//

import UIKit
import AVFoundation

protocol MainViewControllerDelegate {
    func setFileName(atIndex: Int, name: String)
}

class MainViewController: UIViewController {
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var recButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    
    var players = [AVAudioPlayer?]()
    var fileNames = Array<String>(repeating: "", count: 16)
    var delegate: MainViewControllerDelegate?
    var fileManager = FileManager()
    var modeNum = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // sample
//        fileNames[0] = "hosaka"
//        fileNames[1] = "kirin"
//        fileNames[2] = "taguchi"
//        fileNames[3] = "touyou"
        
        delegate = self
        
        setPlayers()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toEditView" {
            let viewController = segue.destination as! EditViewController
            viewController.delegate = delegate
        }
    }
    
    fileprivate func setPlayers() {
        
        players = []
        
        for fileName in fileNames {
            print(fileName)
            let url = documentFilePath(fileName)
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                print("load clear")
                player.prepareToPlay()
                players.append(player)
            } catch {
                players.append(nil)
            }
        }
    }
    
    private func documentFilePath(_ name: String) -> URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dirUrl = urls[0]
        return dirUrl.appendingPathComponent(name)
    }
    
    @IBAction func tapMPCButton(_ sender: UIButton) {
        if sender.tag >= players.count {
            return
        }
        
        if players[sender.tag]?.isPlaying ?? false {
            players[sender.tag]?.stop()
            players[sender.tag]?.currentTime = 0.0
            players[sender.tag]?.numberOfLoops = 1
            players[sender.tag]?.play()
        } else {
            players[sender.tag]?.numberOfLoops = 1
            players[sender.tag]?.play()
        }
    }
    
    @IBAction func pushEditButton() {
        performSegue(withIdentifier: "toEditView", sender: nil)
    }
}

extension MainViewController: MainViewControllerDelegate {
    func setFileName(atIndex: Int, name: String) {
        fileNames[atIndex] = name
        setPlayers()
    }
}

