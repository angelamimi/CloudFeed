//
//  CommentCell.swift
//  Commentz
//
//  Created by Angela Jarosz on 6/7/26.
//  Copyright © 2026 Angela Jarosz. All rights reserved.
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
protocol CommentCellDelegate: AnyObject {
    func deleteComment(commentId: String)
    func editComment(commentId: String, comment: String)
}

class CommentCell: UITableViewCell {
    
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var commentLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var menuButton: UIButton!
    
    weak var delegate: CommentCellDelegate?
    
    var commentId: String?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        MainActor.assumeIsolated { [weak self] in
            self?.initCell()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()

        commentId = nil
        delegate = nil
        menuButton.isHidden = true
    }
    
    private func initCell() {
        
        focusEffect = UIFocusHaloEffect()
        
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
        profileImageView.layer.masksToBounds = true
        
        let deleteAction = UIAction(title: Strings.CommentsActionDelete, image: UIImage(systemName: "trash"), handler: { [weak self] _ in
            self?.delegate?.deleteComment(commentId: self?.commentId ?? "")
        })
        
        let editAction = UIAction(title: Strings.CommentsActionEdit, image: UIImage(systemName: "pencil"), handler: { [weak self] _ in
            self?.delegate?.editComment(commentId: self?.commentId ?? "", comment: self?.commentLabel.text ?? "")
        })
        
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.menu = UIMenu(children: [editAction, deleteAction])
    }
}
