//
//  ViewController.swift
//  Checkitout
//
//  Created by 藤井陽介 on 2017/02/22.
//  Copyright © 2017年 touyou. All rights reserved.
//

import UIKit
import AVFoundation
import EZAudioiOS
import RealmSwift

enum Mode {
    case play
    case record
    case edit
}

class MainViewController: UIViewController {
    
    // MARK: - EZAudio
    @IBOutlet weak var showWaveView: EZAudioPlot!
    var audioPlot: EZAudioPlot!
    var ezMic: EZMicrophone?
    var ezaudioPlayer:EZAudioPlayer!
    var audioFile:EZAudioFile!
    
    // MARK: - Normal
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.delegate = self
            tableView.dataSource = self
            tableView.allowsSelection = false
            tableView.tableFooterView = UIView()
            tableView.backgroundColor = #colorLiteral(red: 0.4635950923, green: 0.4756785631, blue: 0.4834695458, alpha: 1)
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
    @IBOutlet var mpcButton: [UIButton]!
    
    let fileName = "temp.wav"
    let saveData = UserDefaults.standard
    
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    var selectedNum: Int?
    var players = [AVAudioPlayer?]()
    var selectedUrl = Array<URL?>(repeating: nil, count: 16)
    var fileManager = FileManager()
    var mode = Mode.play
    var soundData = [SoundData]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if !saveData.bool(forKey: "isFirstLaunch") {
            loadDocument()
        }
        
        initData()
        
        ezAudioSetup()
        setPlayers()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        mpcButton.forEach {
            $0.imageView?.contentMode = .scaleAspectFit
            $0.contentHorizontalAlignment = .fill
            $0.contentVerticalAlignment = .fill
        }
    }
    
    func loadDocument() {
        #if DEBUG
            addRealm("hosaka", name: "保坂", isBundle: true)
            addRealm("kirin", name: "麒麟", isBundle: true)
            addRealm("taguchi", name: "しゅんぺーさん", isBundle: true)
            addRealm("1korekara_cut", name: "これから", isBundle: true)
            addRealm("2korekara_cut", name: "これから２", isBundle: true)
            addRealm("3apuri_cut", name: "アプリ", isBundle: true)
            addRealm("4setumei_cut", name: "説明", isBundle: true)
            addRealm("5suruze_cut", name: "するぜ", isBundle: true)
            addRealm("6onsei_cut", name: "音声", isBundle: true)
            addRealm("7rokuon_cut", name: "録音", isBundle: true)
            addRealm("8minnnawo_cut", name: "みんなを", isBundle: true)
            addRealm("9rockon_cut", name: "ロックオン", isBundle: true)
            addRealm("10korede_cut", name: "これで", isBundle: true)
            addRealm("11yourname_cut", name: "君の名", isBundle: true)
            addRealm("12todoroku_cut", name: "轟く", isBundle: true)
            addRealm("13menber_cut", name: "メンバー", isBundle: true)
            addRealm("14menta-_cut", name: "メンター", isBundle: true)
        #endif
        
        addRealm("touyou", name: "バスドラ", isBundle: true)
        addRealm("15minnade_cut", name: "みんなで", isBundle: true)
        addRealm("16chekera_cut", name: "チェケラ", isBundle: true)
        
        let assignDef = ["touyou", "15minnade_cut", "16chekera_cut"]
        
        for i in 0 ..< assignDef.count {
            if let data = SoundData.assignDefault(assignDef[i]) {
                data.update {
                    data.padNum = i
                }
            }
        }
        
        
        saveData.set(true, forKey: "isFirstLaunch")
    }
    
    func initData() {
        soundData = SoundData.loadAll()
        
        for sound in soundData {
            if sound.padNum != -1 {
                selectedUrl[sound.padNum] = sound.url
            }
        }
        
        tableView.reloadData()
    }
    
    func addRealm(_ url: String, name: String, isBundle: Bool) {
        let object = SoundData.create()
        object.isBundle = isBundle
        object.urlStr = url
        object.displayName = name
        object.save()
    }
    
    func setPlayers() {
        let session = AVAudioSession.sharedInstance()
        try! session.setCategory(.ambient)
        try! session.setActive(true)
        
        players = []
        
        for url in selectedUrl {
            if let url = url {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.volume = 1.0
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
        try! session.setCategory(.playAndRecord)
        try! session.setActive(true)
        
        let recordSetting: [String: Any] = [
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 16,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100.0
        ]
        
        do {
            try audioRecorder = AVAudioRecorder(url: File(directory: .document, fileName: fileName).url, settings: recordSetting)
        } catch {
            print("error")
        }
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
                if soundData[selected].padNum != -1 {
                    selectedUrl[soundData[selected].padNum] = nil
                }
                
                if let url = selectedUrl[sender.tag], let data = SoundData.fetch(url, isBundle: url.absoluteString.contains("Bundle")) {
                    data.update {
                        data.padNum = -1
                    }
                }
                
                selectedUrl[sender.tag] = soundData[selected].url
                soundData[selected].update {
                    soundData[selected].padNum = sender.tag
                }
                selectedNum = nil
                let indexPath = IndexPath(row: selected, section: 0)
                tableView.deselectRow(at: indexPath, animated: true)
                initData()
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
        
        if let selected = selectedNum {
            tableView.deselectRow(at: IndexPath(row: selected, section: 0), animated: true)
        }
        
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
        ezAudioMicSet()
    }
    
    @IBAction func tapStopButton() {
        recordButton.isEnabled = true
        stopRecordButton.isEnabled = false
        playRecordButton.isEnabled = true
        
        audioRecorder?.stop()
        ezAudioMicStop()
    }
    
    @IBAction func tapPlayButton() {
        do {
            try audioPlayer = AVAudioPlayer(contentsOf: File(directory: .document, fileName: fileName).url)
        } catch {
            print("error")
        }
        
        audioPlayer?.play()
    }
    
    @IBAction func tapSaveButton() {
        guard let titleText = titleTextField.text, titleText != "" else {
            let alert = UIAlertController(title: "ERROR", message: "名前を設定してください。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        let file = Date().description + ".wav"
        
        if Filer.mv(.document, srcPath: fileName, toPath: file) {
            let alert = UIAlertController(title: "セーブ完了しました。", message: "\(titleText)を保存しました。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            present(alert, animated: true, completion: {
                self.showWaveView.clear()
                self.titleTextField.text = nil
                self.addRealm(File(directory: .document, fileName: file).url.absoluteString, name: titleText, isBundle: false)
                self.initData()
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
        return soundData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "musicCell", for: indexPath) as! CustomTableViewCell
        
        cell.fileNameLabel.text = soundData[indexPath.row].displayName
        
        if soundData[indexPath.row].padNum != -1 {
            cell.setNameLabel.text = "PAD \(soundData[indexPath.row].padNum + 1)"
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


// MARK: - 波形表示
extension MainViewController: EZMicrophoneDelegate, EZAudioFileDelegate, EZAudioPlayerDelegate {
    func ezAudioSetup(){
        ezMic = EZMicrophone()
        showWaveView.plotType = EZPlotType.buffer
        
        ezMic?.delegate = self
        
        showWaveView.backgroundColor = UIColor.init(red: 99.0/255.0, green: 102.0/255.0, blue: 104.0/255.0, alpha: 1.0)
        showWaveView.color = UIColor.black
        showWaveView.plotType = EZPlotType.rolling //表示の仕方 Buffer or Rolling
        showWaveView.shouldFill = true            //グラフの表示
        showWaveView.shouldMirror = true
        showWaveView.shouldCenterYAxis = true
    }
    
    func ezAudioMicSet(){
        showWaveView.clear()
        ezMic?.microphoneOn = true
        ezMic!.startFetchingAudio()
    }
    
    func ezAudioMicStop(){
        ezMic?.stopFetchingAudio()
    }
    
    func microphone(_ microphone: EZMicrophone!, hasAudioReceived buffer: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!, withBufferSize bufferSize: UInt32, withNumberOfChannels numberOfChannels: UInt32) {
        
        DispatchQueue.main.async {
            self.showWaveView.updateBuffer(buffer[0], withBufferSize: bufferSize)
        }
    }
}
