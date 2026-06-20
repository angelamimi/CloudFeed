//
//  CommentsViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 6/9/26.
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
protocol CommentsDelegate: AnyObject {
    func loadComplete(count: Int?)
    func addComplete(error: Bool)
    func updateComplete(error: Bool)
    func deleteComplete(error: Bool)
    func deleteBegin()
    func editComment(commentId: String)
}

@MainActor
final class CommentsViewModel {
    
    private let dataService: DataService
    private let metadata: Metadata
    
    private var tableDataSource: UITableViewDiffableDataSource<Int, FileComment.ID>!
    private var comments: [FileComment.ID: FileComment] = [:]
    
    private let cacheManager: CacheManager
    private weak var delegate: CommentsDelegate!
    
    init(dataService: DataService, delegate: CommentsDelegate, cacheManager: CacheManager, metadata: Metadata) {
        self.dataService = dataService
        self.metadata = metadata
        self.delegate = delegate
        self.cacheManager = cacheManager
    }
    
    func getCommentById(_ commentId: String) -> String? {
        return comments[commentId]?.message
    }
    
    func loadComments() async {
        
        if let account = Environment.current.currentUser?.account,
           let comments = await dataService.getComments(fileId: metadata.fileId, account: account) {
            
            DispatchQueue.main.async { [weak self] in
                self?.showComments(comments)
            }
        } else {
            delegate.loadComplete(count: nil)
        }
    }
    
    func addComment(commentText: String?) async {
        
        guard let text = commentText?.trimmingCharacters(in: .whitespacesAndNewlines), text.isEmpty == false else {
            delegate.addComplete(error: true)
            return
        }
        
        let error = await dataService.addComment(fileId: metadata.fileId, account: metadata.account, message: text)
        
        if error {
            delegate.addComplete(error: true)
        } else {
            delegate.updateComplete(error: false)
            await loadComments()
        }
    }
    
    func updateComment(commentId: String, commentText: String?) async {
        
        guard let text = commentText?.trimmingCharacters(in: .whitespacesAndNewlines), text.isEmpty == false else {
            delegate.updateComplete(error: true)
            return
        }
        
        let error = await dataService.updateComment(fileId: metadata.fileId, account: metadata.account, messageId: commentId, message: text)
        
        if error {
            delegate.updateComplete(error: true)
        } else {
            delegate.updateComplete(error: false)
            await loadComments()
        }
    }
    
    func initDatasource(_ tableView: UITableView) {
        
        let nib = UINib(nibName: "CommentCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "CommentCell")
        
        tableDataSource = UITableViewDiffableDataSource<Int, FileComment.ID>(tableView: tableView) { [weak self] tableView, indexPath, itemIdentifier in
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as? CommentCell else { fatalError("Cannot create new cell") }
            self?.populateCell(commentId: itemIdentifier, cell: cell, indexPath: indexPath)
            return cell
        }
        
        var snapshot = tableDataSource.snapshot()
        snapshot.appendSections([0])
        tableDataSource.applySnapshotUsingReloadData(snapshot)
    }
    
    func getCommenterAvatar(userId: String, urlBase: String) -> UIImage? {
        
        let avatarPath = dataService.store.getAvatarPath(userId, urlBase)
        
        if FileManager.default.fileExists(atPath: avatarPath) {
                
            let image = UIImage(contentsOfFile: avatarPath)
            
            if image != nil {
                cacheManager.cache(urlBase: urlBase, userId: userId, image: image!)
            }
            
            return image
        }
        
        return nil
    }
    
    func loadCommenterAvatar(userId: String, urlBase: String, account: String, delegate: DownloadAvatarOperationDelegate) -> UIImage? {
        
        let avatarPath = dataService.store.getAvatarPath(userId, urlBase)
        
        if let cachedAvatar = cacheManager.cached(urlBase: urlBase, userId: userId) {
            return cachedAvatar
        } else {
            if FileManager.default.fileExists(atPath: avatarPath) {
                    
                let image = UIImage(contentsOfFile: avatarPath)
                
                if image != nil {
                    cacheManager.cache(urlBase: urlBase, userId: userId, image: image!)
                }
                
                return image
            } else {
                //note: id is not used here. there's only one metadata to download for
                cacheManager.download(objectId: metadata.id, userId: userId, urlBase: urlBase, account: account, delegate: delegate)
            }
        }
        
        return nil
    }
    
    private func showComments(_ comments: [FileComment]) {
        
        let count = comments.count
        
        if count == 0 {
            delegate.loadComplete(count: count)
        } else {
            var snapshot = tableDataSource.snapshot()
            
            snapshot.deleteAllItems()
            snapshot.appendSections([0])
            
            for comment in comments {
                self.comments[comment.id] = comment
                snapshot.appendItems([comment.id], toSection: 0)
            }
            
            tableDataSource.applySnapshotUsingReloadData(snapshot, completion: { [weak self] in
                self?.delegate.loadComplete(count: count)
            })
        }
    }
    
    private func populateCell(commentId: String, cell: CommentCell, indexPath: IndexPath) {
        
        guard let comment = comments[commentId] else { return }
        
        cell.delegate = self
        cell.commentId = commentId
        
        let attributedComment = NSMutableAttributedString(string: comment.message, attributes: [NSAttributedString.Key.font : UIFont.preferredFont(forTextStyle: .body)])
        let attributedSpace = NSMutableAttributedString(string: " ", attributes: [NSAttributedString.Key.font : UIFont.preferredFont(forTextStyle: .body)])
        let boldAttributes = [NSAttributedString.Key.font : UIFont.preferredFont(forTextStyle: .body, compatibleWith: UITraitCollection(legibilityWeight: .bold))]
        let attributedName = NSMutableAttributedString(string: comment.actorDisplayName, attributes: boldAttributes)
        
        attributedName.append(attributedSpace)
        attributedName.append(attributedComment)
        
        cell.commentLabel.attributedText = attributedName
        
        cell.profileImageView.image = UIImage.init(systemName: "person.crop.circle")
        cell.dateLabel.text = comment.creationDateTime.formatted(date: .abbreviated, time: .shortened)
        
        if comment.actorId == Environment.current.currentUser?.userId {
            cell.menuButton.isHidden = false
        } else {
            cell.menuButton.isHidden = true
        }
        
        let avatarPath = dataService.store.getAvatarPath(comment.actorId, metadata.urlBase)
        
        if let cachedAvatar = cacheManager.cached(urlBase: metadata.urlBase, userId: comment.actorId) {
            cell.profileImageView.image = cachedAvatar
        } else {
            if FileManager.default.fileExists(atPath: avatarPath) {
                
                autoreleasepool {
                    
                    let image = UIImage(contentsOfFile: avatarPath)
                    cell.profileImageView?.image = image
                    
                    if image != nil {
                        cacheManager.cache(urlBase: metadata.urlBase, userId: comment.actorId, image: image!)
                    }
                }
            } else {
                cacheManager.download(objectId: comment.id, userId: comment.actorId, urlBase: metadata.urlBase, account: metadata.account, delegate: self)
            }
        }
    }
    
    private func handleDeleteCommentAction(commentId: String) {
        
        delegate.deleteBegin()
        
        Task { [weak self] in
            
            if let account = Environment.current.currentUser?.account, let fileId = self?.metadata.fileId {
                
                let error = await self?.dataService.deleteComment(fileId: fileId, account: account, messageId: commentId)

                if error == nil || error == true {
                    self?.delegate.deleteComplete(error: true)
                } else {
                    self?.delegate.deleteComplete(error: false)
                    await self?.loadComments()
                }
            }
        }
    }
    
    private func handleAvatarDownloaded(_ id: String) {
        
        var snapshot = tableDataSource.snapshot()
        let displayed = snapshot.itemIdentifiers(inSection: 0)
        
        if displayed.contains(id), let comment = comments[id] {
            
            let path = dataService.store.getAvatarPath(comment.actorId, metadata.urlBase)
            
            if FileManager.default.fileExists(atPath: path) {
                snapshot.reconfigureItems([comment.id])
                tableDataSource.apply(snapshot)
            }
        }
    }
}

extension CommentsViewModel: CommentCellDelegate {
    
    func deleteComment(commentId: String) {
        handleDeleteCommentAction(commentId: commentId)
    }
    
    func editComment(commentId: String, comment: String) {
        delegate?.editComment(commentId: commentId)
    }
}

extension CommentsViewModel: DownloadAvatarOperationDelegate {
    
    func avatarDownloaded(id: String) {
        handleAvatarDownloaded(id)
    }
}
