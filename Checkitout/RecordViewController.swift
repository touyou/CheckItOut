//
//  RecordViewController.swift
//  Checkitout
//
//  Created by 藤井陽介 on 2017/02/22.
//  Copyright © 2017年 touyou. All rights reserved.
//

import UIKit
import AVFoundation

class RecordViewController: UIViewController {

    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton! {
        didSet {
            playButton.isEnabled = false
        }
    }
    @IBOutlet weak var stopButton: UIButton! {
        didSet {
            stopButton.isEnabled = false
        }
    }
    
    let fileName = "temp.wav"
    var fileManager = FileManager()
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    var selectedNum: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        titleTextField.text = "sample"
        
        setupAudioRecorder()
    }
    
    private func setupAudioRecorder() {
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
    
    private func documentFilePath(_ name: String) -> URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dirUrl = urls[0]
        return dirUrl.appendingPathComponent(name)
    }
    
    @IBAction func pushRecordButton() {
        recordButton.isEnabled = false
        stopButton.isEnabled = true
        playButton.isEnabled = false
        
        audioRecorder?.record()
    }
    
    @IBAction func pushStopButton() {
        recordButton.isEnabled = true
        stopButton.isEnabled = false
        playButton.isEnabled = true
        
        audioRecorder?.stop()
    }
    
    @IBAction func pushPlayButton() {
        do {
            try audioPlayer = AVAudioPlayer(contentsOf: documentFilePath(fileName))
        } catch {
            print("error")
        }
        
        audioPlayer?.play()
    }
    
    @IBAction func pushSaveButton() {
        do {
            try fileManager.moveItem(at: documentFilePath(fileName), to: documentFilePath(titleTextField.text! + ".wav"))
            
            dismiss(animated: true, completion: nil)
        } catch {
            let alert = UIAlertController(title: "ERROR", message: "セーブに失敗しました。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
}
