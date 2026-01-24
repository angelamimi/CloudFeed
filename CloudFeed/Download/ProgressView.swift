//
//  ProgressView.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 5/16/25.
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

@MainActor
protocol ProgressDelegate: AnyObject {
    func progressCancelled()
}

class ProgressView: UIView {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var downloadingLabel: UILabel!
    @IBOutlet weak var cancelLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    
    weak var delegate: ProgressDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initSubviews()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()

        MainActor.assumeIsolated {
            awake()
        }
    }
    
    func setLabelText(downloading: String, cancel: String) {
        downloadingLabel.text = downloading
        cancelLabel.text = cancel
    }
    
    private func awake() {
        stackView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        stackView.layer.cornerRadius = 8
    }
    
    private func initSubviews() {
        
        let nib = UINib(nibName: "ProgressView", bundle: Bundle(for: type(of: self)))
        let container = nib.instantiate(withOwner: self, options: nil).first as! UIView
        
        addSubview(container)
        
        container.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leftAnchor.constraint(equalTo: leftAnchor),
            container.rightAnchor.constraint(equalTo: rightAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    @objc
    func tapped() {
        delegate?.progressCancelled()
    }
    
    func setProgress(_ progress: Float) {
        progressView.progress = progress
    }
}
