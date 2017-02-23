//
//  ViewController.swift
//  Checkitout
//
//  Created by 藤井陽介 on 2017/02/22.
//  Copyright © 2017年 touyou. All rights reserved.
//

import UIKit
import AVFoundation

enum Mode {
    case play
    case record
    case edit
}

class MainViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.delegate = self
            tableView.dataSource = self
            tableView.allowsSelection = false
        }
    }
    @IBOutlet weak var playButton: UIButton! {
        didSet {
            playButton.isEnabled = false
        }
    }
    @IBOutlet weak var recButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var containerView: UIView! {
        didSet {
            containerView.isHidden = true
        }
    }
    @IBOutlet weak var titleTextField: UITextField! {
        didSet {
            titleTextField.delegate = self
        }
    }
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playRecordButton: UIButton! {
        didSet {
            playRecordButton.isEnabled = false
        }
    }
    @IBOutlet weak var stopRecordButton: UIButton! {
        didSet {
            stopRecordButton.isEnabled = false
        }
    }
    
    let fileName = "temp.wav"
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    var selectedNum: Int?
    var players = [AVAudioPlayer?]()
    var selectedUrl = Array<URL?>(repeating: nil, count: 16)
    var mapToNumber = Dictionary<String, Int>()
    var fileManager = FileManager()
    var mode = Mode.play
    var fileUrl = [URL]()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadDocument()
        
        setPlayers()
    }
    
    func loadDocument() {
        fileUrl = []
        // sample
        fileUrl.append(Bundle.main.url(forResource: "hosaka", withExtension: "wav")!)
        fileUrl.append(Bundle.main.url(forResource: "kirin", withExtension: "wav")!)
        fileUrl.append(Bundle.main.url(forResource: "taguchi", withExtension: "wav")!)
        fileUrl.append(Bundle.main.url(forResource: "touyou", withExtension: "wav")!)
        
        for i in 0 ..< 4 {
            selectedUrl[i] = fileUrl[i]
            mapToNumber[fileUrl[i].absoluteString] = i
        }

        let files = Filer.ls(.document)
        if let files = files {
            for file in files {
                fileUrl.append(file.url)
            }
        } else {
            print("load失敗🙅")
        }
    }
    
    func setPlayers() {
        players = []
        
        for url in selectedUrl {
            if let url = url {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    players.append(player)
                } catch {
                    players.append(nil)
                }
            } else {
                players.append(nil)
            }
        }
    }
    
    func setupAudioRecorder() {
        let session = AVAudioSession.sharedInstance()
        try! session.setCategory(AVAudioSessionCategoryPlayAndRecord)
        try! session.setActive(true)
        
        let recordSetting: [String: Any] = [
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 16,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100.0
        ]
        
        do {
            try audioRecorder = AVAudioRecorder(url: documentFilePath(fileName), settings: recordSetting)
        } catch {
            print("error")
        }
    }

    
    fileprivate func documentFilePath(_ name: String) -> URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dirUrl = urls[0]
        return dirUrl.appendingPathComponent(name)
    }
    
    // MARK: - MPC Button
    
    @IBAction func tapMPCButton(_ sender: UIButton) {
        switch mode {
        case .play:
            if players[sender.tag]?.isPlaying ?? false {
                players[sender.tag]?.stop()
                players[sender.tag]?.currentTime = 0.0
                players[sender.tag]?.play()
            } else {
                players[sender.tag]?.play()
            }
        case .edit:
            // 選択した数字があればその
            if let selected = selectedNum {
                let str = fileUrl[selected].absoluteString
                if let num = mapToNumber[str] {
                    selectedUrl[num] = nil
                }
                
                selectedUrl[sender.tag] = fileUrl[selected]
                mapToNumber[str] = sender.tag
                selectedNum = nil
                let indexPath = IndexPath(row: selected, section: 0)
                tableView.deselectRow(at: indexPath, animated: true)
                tableView.reloadData()
            }
        case .record: break
        }
        
    }
    
    // MARK: - Mode Button
    
    @IBAction func pushEditButton() {
        mode = .edit
        containerView.isHidden = true
        
        playButton.isEnabled = true
        editButton.isEnabled = false
        recButton.isEnabled = true
        
        tableView.allowsSelection = true
    }
    
    @IBAction func pushPlayButton() {
        mode = .play
        containerView.isHidden = true
        
        playButton.isEnabled = false
        editButton.isEnabled = true
        recButton.isEnabled = true
        
        tableView.allowsSelection = false
        
        loadDocument()
        setPlayers()
    }
    
    @IBAction func pushRecordButton() {
        mode = .record
        containerView.isHidden = false
        
        playButton.isEnabled = true
        editButton.isEnabled = true
        recButton.isEnabled = false
        
        recordButton.isEnabled = true
        stopRecordButton.isEnabled = false
        playRecordButton.isEnabled = false
        
        setupAudioRecorder()
    }
    
    // MARK: - Record Button
    
    @IBAction func tapRecordButton() {
        recordButton.isEnabled = false
        stopRecordButton.isEnabled = true
        playRecordButton.isEnabled = false
        
        audioRecorder?.record()
    }
    
    @IBAction func tapStopButton() {
        recordButton.isEnabled = true
        stopRecordButton.isEnabled = false
        playRecordButton.isEnabled = true
        
        audioRecorder?.stop()
    }
    
    @IBAction func tapPlayButton() {
        do {
            try audioPlayer = AVAudioPlayer(contentsOf: documentFilePath(fileName))
        } catch {
            print("error")
        }
        
        audioPlayer?.play()
    }
    
    @IBAction func tapSaveButton() {
        guard let titleText = titleTextField.text, titleText != "" else {
            let alert = UIAlertController(title: "ERROR", message: "ファイル名を設定してください。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        if Filer.mv(.document, srcPath: fileName, toPath: titleText + ".wav") {
            let alert = UIAlertController(title: "セーブ完了しました。", message: "\(titleText).wavを保存しました。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            present(alert, animated: true, completion: {
                self.loadDocument()
                self.tableView.reloadData()
            })
        } else {
            let alert = UIAlertController(title: "ERROR", message: "セーブに失敗しました。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)

        }
    }

}

extension MainViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileUrl.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "musicCell", for: indexPath) as! CustomTableViewCell
        
        let fileNameStr = fileUrl[indexPath.row].absoluteString
        let list = fileNameStr.components(separatedBy: "/")
        cell.fileNameLabel.text = list[list.count-1]
        
        if let num = mapToNumber[fileNameStr] {
            cell.setNameLabel.text = "PAD \(num)"
        } else {
            cell.setNameLabel.text = "NONE"
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedNum = indexPath.row
    }
}

extension MainViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return textField.resignFirstResponder()
    }
}
