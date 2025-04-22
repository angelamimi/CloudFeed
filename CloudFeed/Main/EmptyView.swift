//
//  EmptyView.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/6/23.
//  Copyright © 2023 Angela Jarosz. All rights reserved.
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

class EmptyView: UIView {
    
    internal var view : UIView!
    
    @IBOutlet weak var titleLabel : UILabel!
    @IBOutlet weak var descriptionLabel : UILabel!
    @IBOutlet weak var emptyImage : UIImageView!
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: EmptyView.self)
    )
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initView()
    }
    
    func display(image: UIImage?, title: String, description: String) {
        emptyImage.image = image
        titleLabel.text = title
        descriptionLabel.text = description
    }
    
    func hide(animate: Bool = true) {
        setVisibility(isHidden: true, animate: animate)
    }
    
    func show() {
        setVisibility(isHidden: false, animate: true)
    }
    
    func updateText(title: String, description: String) {
        titleLabel.text = title
        descriptionLabel.text = description
    }
    
    private func setVisibility(isHidden: Bool, animate: Bool) {
        if animate {
            if isHidden == false {
                self.isHidden = isHidden
            }
            UIView.animate(withDuration: 0.4, animations: { [weak self] in
                self?.alpha = isHidden ? 0 : 1
            }, completion: { [weak self] _ in
                self?.isHidden = isHidden
            })
        } else {
            self.isHidden = isHidden
            alpha = isHidden ? 0 : 1
        }
    }
    
    private func initView() {
        
        view = loadViewFromNib()
        
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        alpha = 0
        
        addSubview(view)
    }
    
    private func loadViewFromNib() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: "EmptyView", bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
 
        return view
    }
}
