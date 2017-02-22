//
//  EditViewController.swift
//  Checkitout
//
//  Created by 藤井陽介 on 2017/02/22.
//  Copyright © 2017年 touyou. All rights reserved.
//

import UIKit

class EditViewController: UIViewController {
    
    var delegate: MainViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toRecordView" {
            let viewController = segue.destination as! RecordViewController
            viewController.delegate = delegate
            viewController.selectedNum = sender as? Int
        }
    }
    
    @IBAction func tapEditButton(_ sender: UIButton) {
        performSegue(withIdentifier: "toRecordView", sender: sender.tag)
    }
    
    @IBAction func pushExitButton() {
        dismiss(animated: true, completion: nil)
    }
}
