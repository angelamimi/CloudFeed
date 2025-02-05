//
//  CertificateController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 1/31/25.
//  Copyright © 2025 Angela Jarosz. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import os.log
import UIKit

protocol CertificateDelegate {
    func certificateDisplayError()
}

class CertificateController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    var host: String!
    var certificateDirectory: URL!
    
    var delegate: CertificateDelegate?
    
    override func viewDidLoad() {
        
        let path = certificateDirectory.path + "/" + host + ".txt"
        
        if FileManager.default.fileExists(atPath: path) {
            do {
                let text = try String(contentsOfFile: path, encoding: .utf8)
                textView.text = text
            } catch {
                delegate?.certificateDisplayError()
            }
        } else {
            delegate?.certificateDisplayError()
        }
    }
}
