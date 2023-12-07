//
//  EmptyView.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/6/23.
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
        self.emptyImage.image = image
        self.titleLabel.text = title
        self.descriptionLabel.text = description
    }
    
    private func initView() {
        view = loadViewFromNib()
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
 
        addSubview(view)
    }
    
    private func loadViewFromNib() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: "EmptyView", bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
 
        return view
    }
}
