//
//  CustomTableViewCell.swift
//  Checkitout
//
//  Created by 藤井陽介 on 2017/02/22.
//  Copyright © 2017年 touyou. All rights reserved.
//

import UIKit

class CustomTableViewCell: UITableViewCell {
    
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var setNameLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
