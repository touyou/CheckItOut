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
        
        print(Bundle.main.url(forResource: "hosaka", withExtension: "wav")!.absoluteString)
        
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
        addRealm(Bundle.main.url(forResource: "hosaka", withExtension: "wav")!, name: "保坂")
        addRealm(Bundle.main.url(forResource: "kirin", withExtension: "wav")!, name: "麒麟")
        addRealm(Bundle.main.url(forResource: "taguchi", withExtension: "wav")!, name: "しゅんぺーさん")
        addRealm(Bundle.main.url(forResource: "touyou", withExtension: "wav")!, name: "バスドラ")
        addRealm(Bundle.main.url(forResource: "1korekara_cut", withExtension: "wav")!, name: "これから")
        addRealm(Bundle.main.url(forResource: "2korekara_cut", withExtension: "wav")!, name: "これから２")
        addRealm(Bundle.main.url(forResource: "3apuri_cut", withExtension: "wav")!, name: "アプリ")
        addRealm(Bundle.main.url(forResource: "4setumei_cut", withExtension: "wav")!, name: "説明")
        addRealm(Bundle.main.url(forResource: "5suruze_cut", withExtension: "wav")!, name: "するぜ")
        addRealm(Bundle.main.url(forResource: "6onsei_cut", withExtension: "wav")!, name: "音声")
        addRealm(Bundle.main.url(forResource: "7rokuon_cut", withExtension: "wav")!, name: "録音")
        addRealm(Bundle.main.url(forResource: "8minnnawo_cut", withExtension: "wav")!, name: "みんなを")
        addRealm(Bundle.main.url(forResource: "9rockon_cut", withExtension: "wav")!, name: "ロックオン")
        addRealm(Bundle.main.url(forResource: "10korede_cut", withExtension: "wav")!, name: "これで")
        addRealm(Bundle.main.url(forResource: "11yourname_cut", withExtension: "wav")!, name: "君の名")
        addRealm(Bundle.main.url(forResource: "12todoroku_cut", withExtension: "wav")!, name: "轟く")
        addRealm(Bundle.main.url(forResource: "13menber_cut", withExtension: "wav")!, name: "メンバー")
        addRealm(Bundle.main.url(forResource: "14menta-_cut", withExtension: "wav")!, name: "メンター")
        addRealm(Bundle.main.url(forResource: "15minnade_cut", withExtension: "wav")!, name: "みんなで")
        addRealm(Bundle.main.url(forResource: "16chekera_cut", withExtension: "wav")!, name: "チェケラ")
        
        
        saveData.set(true, forKey: "isFirstLaunch")
    }
    
    func initData() {
        soundData = SoundData.loadAll()
        
        for sound in soundData {
            if sound.padNum != -1 {
                selectedUrl[sound.padNum] = sound.url
            }
        }
    }
    
    func addRealm(_ url: URL, name: String) {
        let object = SoundData.create()
        object.urlStr = url.absoluteString
        object.displayName = name
        object.save()
    }
    
    func setPlayers() {
        let session = AVAudioSession.sharedInstance()
        try! session.setCategory(AVAudioSessionCategoryAmbient)
        try! session.setActive(true)
        
        players = []
        
        print("debug----")
        for url in selectedUrl {
            if let url = url {
                print(url.absoluteString)
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.volume = 1.0
                    print("loaded")
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
                
                if let url = selectedUrl[sender.tag], let data = SoundData.fetch(url.absoluteString) {
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
                self.addRealm(File(directory: .document, fileName: file).url, name: titleText)
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
