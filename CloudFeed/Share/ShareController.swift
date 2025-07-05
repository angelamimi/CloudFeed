//
//  ShareController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 7/3/25.
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

import UIKit

class ShareController: UIViewController {
    
    @IBOutlet weak var progressView: ProgressView!
    
    var viewModel: ShareViewModel?
    var metadatas: [Metadata] = []
    
    override func viewDidLoad() {
        progressView.delegate = self
        viewModel?.share(metadatas)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.2)
    }
}

extension ShareController: DownloadDelegate {
    
    func progressUpdated(_ progress: Double) {
        if view.subviews.last is ProgressView {
            let currentProgress = progressView.progressView.progress
            progressView.progressView.setProgress(currentProgress + Float(progress), animated: true)
        }
    }
}

extension ShareController: ProgressDelegate {
    
    func progressCancelled() {
        viewModel?.cancelDownloads()
        dismiss(animated: true)
    }
}
