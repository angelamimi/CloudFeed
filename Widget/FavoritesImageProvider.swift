//
//  FavoritesImageProvider.swift
//  Widget
//
//  Created by Angela Jarosz on 1/27/26.
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
import WidgetKit
import Intents
import SwiftUI
import SwiftData
import NextcloudKit
internal import Alamofire

final class FavoritesImageProvider: AppIntentTimelineProvider {

    typealias Entry = ImageDataEntry
    typealias Intent = ConfigurationAppIntent

    init() {
        clearFavoriteData()
    }
    
    func placeholder(in context: Context) -> ImageDataEntry {
        return ImageDataEntry(date: .now, showDate: false, image: nil, title: "", url: URL(string: Global.shared.widgetScheme + "://")!, message: NSLocalizedString("Widget.Favorites.SignIn", comment: ""))
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> ImageDataEntry {
        let result = await getImageDataEntry(for: configuration, context: context, familyOverride: "", isPreview: false)
        return result.entry
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<ImageDataEntry> {
        return await getTimeline(for: configuration, in: context)
    }
}

extension FavoritesImageProvider {
    
    private func clearFavoriteData() {
        let store = StoreUtility()
        store.clearWidgetFavoriteData("")
        store.clearWidgetFavoriteData(WidgetFamily.systemSmall.description)
        store.clearWidgetFavoriteData(WidgetFamily.systemMedium.description)
        store.clearWidgetFavoriteData(WidgetFamily.systemLarge.description)
        store.clearWidgetFavoriteData(WidgetFamily.systemExtraLarge.description)
        store.setWidgetFavoriteLastImageDate(date: nil)
    }
    
    private func getDatabaseManager(_ databaseUrl: URL?) -> DatabaseManager? {
        
        if let url = databaseUrl {
            let container = DatabaseManager.urlContainer(url)
            return DatabaseManager(modelContainer: container)
        }
        
        return nil
    }
    
    private func getTimeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<ImageDataEntry> {
        let result = await getImageDataEntry(for: configuration, context: context, familyOverride: nil, isPreview: context.isPreview)
        
        if result.reloadAtEnd {
            return Timeline(entries: [result.entry], policy: .atEnd)
        } else {
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
            return Timeline(entries: [result.entry], policy: .after(nextUpdate))
        }
    }
    
    private func getImageDataEntry(for configuration: ConfigurationAppIntent, context: Context, familyOverride: String?, isPreview: Bool) async -> (entry: ImageDataEntry, reloadAtEnd: Bool) {
        
        if isPreview {
            let entry = ImageDataEntry(date: .now, showDate: configuration.showDate, image: nil, title: "", url: URL(string: Global.shared.widgetScheme + "://")!, message: NSLocalizedString("Widget.Favorites.SignIn", comment: ""))
            return (entry: entry, reloadAtEnd: false)
        }
        
        let store = StoreUtility()
        let dbUrl = store.databaseDirectory?.appending(path: Global.shared.database)
        let databaseManager: DatabaseManager? = getDatabaseManager(dbUrl)
        let password: String
        let scale = context.environmentVariants.displayScale?.max() ?? 1.0
        
        guard let account = await databaseManager?.getActiveAccount() else {
            let url = URL(string: Global.shared.widgetScheme + "://")!
            let entry = ImageDataEntry(date: .now, showDate: false, image: nil, title: "", url: url, message: NSLocalizedString("Widget.Favorites.SignIn", comment: ""))
            return (entry: entry, reloadAtEnd: false)
        }
        
        if let data = store.getWidgetFavoriteLastImageData(familyOverride == nil ? context.family.description : familyOverride!) {
            
            if .now >= Calendar.current.date(byAdding: .hour, value: 1, to: data.date)! {
                //hour passed
            } else {
                if let widgetUrl = URL(string: data.widgetUrl),
                   let preview = await getImage(data.imagePath, size: context.displaySize, scale: scale) {
                    let entry = ImageDataEntry(date: .now, showDate: configuration.showDate, image: preview, title: data.imageTitle, url: widgetUrl)
                    return (entry: entry, reloadAtEnd: false)
                }
            }
        }
        
        password = store.getPassword(account.account)
        
        NextcloudKit.shared.setup(groupIdentifier: Global.shared.groupIdentifier, delegate: self)
        
        NextcloudKit.shared.appendSession(account: account.account,
                                          urlBase: account.urlBase,
                                          user: account.user,
                                          userId: account.userId,
                                          password: password,
                                          userAgent: Global.shared.userAgent,
                                          httpMaximumConnectionsPerHost: 8,
                                          httpMaximumConnectionsPerHostInDownload: 8,
                                          httpMaximumConnectionsPerHostInUpload: 8,
                                          groupIdentifier: Global.shared.groupIdentifier)
        
        NextcloudKit.configureLogger(logLevel: NKLogLevel.disabled)
        
        let result = await NextcloudKit.shared.listingFavoritesAsync(showHiddenFiles: false, account: account.account)
        
        let filteredFiles = result.files?.filter({ $0.classFile == "image" })
        
        let filtered = filteredFiles?.map({ Metadata.init(file: $0) })
        let sorted = filtered?.sorted(by: { $0.date > $1.date }) ?? []

        let nextMetadata: Metadata?

        let lastImageDate = store.getWidgetFavoriteLastImageDate()
        
        if let date = lastImageDate {
            nextMetadata = sorted.first(where: { $0.date < date })
        } else {
            nextMetadata = sorted.first
        }
        
        if let metadata = nextMetadata {
            
            store.setWidgetFavoriteLastImageDate(date: metadata.date)
            
            let title = metadata.date.formatted(date: .abbreviated, time: .shortened)
            let action = Global.WidgetAction.viewFavorite.rawValue
            let url = URL(string: "\(Global.shared.widgetScheme)://\(action)?ocid=\(metadata.ocId)&etag=\(metadata.etag)&account=\(account.account)")!
            
            let path = store.getPreviewPath(metadata.ocId, metadata.etag)
            
            var image: UIImage? = nil
            
            if store.previewExists(metadata.ocId, metadata.etag) {
                image = await getImage(path, size: context.displaySize, scale: scale)
            } else {
                let iconPath = store.getIconPath(metadata.ocId, metadata.etag)
                image = await downloadPreview(fileId: metadata.fileId, etag: metadata.etag, ocId: metadata.ocId, path: path, iconPath: iconPath, account: account.account, context: context)
            }
            
            if image != nil {
                let data = ImageProviderData(date: .now, widgetUrl: url.description, imagePath: path, imageTitle: title)
                store.setWidgetFavoriteLastImageData(data: data, family: familyOverride == nil ? context.family.description : familyOverride!)
            }
            
            let entry = ImageDataEntry(date: .now, showDate: configuration.showDate, image: image, title: title, url: url, message: nil)
            
            return (entry: entry, reloadAtEnd: false)
            
        } else {
            
            store.setWidgetFavoriteLastImageDate(date: nil)
            
            let url = URL(string: Global.shared.widgetScheme + "://" + Global.WidgetAction.viewFavorite.rawValue)!
            var entry = ImageDataEntry(date: .now, showDate: configuration.showDate, image: nil, title: "", url: url, message: nil)
            
            if sorted.isEmpty {
                entry.message = NSLocalizedString("Widget.Favorites.Empty", comment: "")
                return (entry: entry, reloadAtEnd: false)
            } else {
                return (entry: entry, reloadAtEnd: true)
            }
        }
    }
    
    private func downloadPreview(fileId: String, etag: String, ocId: String, path: String, iconPath: String, account: String, context: Context) async -> UIImage? {
        
        let options = NKRequestOptions(timeout: 30, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        let result = await NextcloudKit.shared.downloadPreviewAsync(fileId: fileId,
                                                                    etag: etag,
                                                                    account: account,
                                                                    options: options)
        
        if result.error == .success, let data = result.responseData?.data {
            ImageUtility.saveImageAtPaths(data: data, previewPath: path, iconPath: iconPath)
            
            let scale = context.environmentVariants.displayScale?.max() ?? 1.0
            return await getImage(path, size: context.displaySize, scale: scale)
        }
        
        return nil
    }
    
    private func getImage(_ path: String, size: CGSize, scale: CGFloat) async -> UIImage? {
        return await ImageUtility.getImageForSize(path, size: size, scale: scale)
    }
}

extension FavoritesImageProvider: NextcloudKitDelegate {
    
    func authenticationChallenge(_ session: URLSession,
                                 didReceive challenge: URLAuthenticationChallenge,
                                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
