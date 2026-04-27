//
//  FeedImageProvider.swift
//  WidgetExtension
//
//  Created by Angela Jarosz on 3/18/26.
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

final class FeedImageProvider: AppIntentTimelineProvider {
    
    typealias Entry = ImageDataEntry
    typealias Intent = ConfigurationAppIntent
    
    func placeholder(in context: Context) -> ImageDataEntry {
        return ImageDataEntry(date: .now, showDate: false, image: nil, title: "", url: URL(string: Global.shared.widgetScheme + "://")!, message: NSLocalizedString("Widget.Feed.SignIn", comment: ""))
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> ImageDataEntry {
        let result = await getImageDataEntry(for: configuration, context: context, familyOverride: "", isPreview: false)
        return result.entry
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<ImageDataEntry> {
        return await getTimeline(for: configuration, in: context)
    }
}

extension FeedImageProvider {
    
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
            let entry = ImageDataEntry(date: .now, showDate: false, image: nil, title: "", url: URL(string: Global.shared.widgetScheme + "://")!, message: NSLocalizedString("Widget.Feed.SignIn", comment: ""))
            return (entry: entry, reloadAtEnd: false)
        }
        
        let store = StoreUtility()
        let scale = context.environmentVariants.displayScale?.max() ?? 1.0
        let cached = store.getWidgetFeedLastImageData(familyOverride == nil ? context.family.description : familyOverride!)
        
        if let data = cached {
            
            if .now >= Calendar.current.date(byAdding: .hour, value: 1, to: data.date)! {
                //hour passed. allow remote fetch
            } else {
                if let widgetUrl = URL(string: data.widgetUrl),
                   let preview = await getImage(data.imagePath, size: context.displaySize, scale: scale) {
                    let entry = ImageDataEntry(date: .now, showDate: configuration.showDate, image: preview, title: data.imageTitle, url: widgetUrl)
                    return (entry: entry, reloadAtEnd: false)
                }
            }
        }
        
        let dbUrl = store.databaseDirectory?.appending(path: Global.shared.database)
        let databaseManager: DatabaseManager? = getDatabaseManager(dbUrl)
        let password: String
        
        guard let account = await databaseManager?.getActiveAccount() else {
            let url = URL(string: Global.shared.widgetScheme + "://")!
            let entry = ImageDataEntry(date: .now, showDate: false, image: nil, title: "", url: url, message: NSLocalizedString("Widget.Feed.SignIn", comment: ""))
            return (entry: entry, reloadAtEnd: false)
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
        
        //check the latest image
        let latestBody = getRequestBody(account.userId, .now)
        let options = NKRequestOptions(timeout: 30, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        let latestResult = await NextcloudKit.shared.searchBodyRequestAsync(serverUrl: account.urlBase, requestBody: latestBody, showHiddenFiles: false, account: account.account, options: options)
                                                                      
        let latestFiltered = latestResult.files?.map({ Metadata.init(file: $0) })
        let latestSorted = latestFiltered?.sorted(by: { $0.date > $1.date }) ?? []
        
        guard let latest = latestSorted.first else {
            store.setWidgetFeedLastImageOcId(ocId: nil)
            store.setWidgetFeedLastImageDate(date: nil)
            return (entry: getEntry(NSLocalizedString("Widget.Feed.Empty", comment: "")), reloadAtEnd: false)
        }
        
        let latestOcId = latest.ocId
        
        if let latestStoredOcId = store.getWidgetFeedLastImageOcId(), latestOcId == latestStoredOcId {
            //nothing new
        } else {
            
            store.setWidgetFeedLastImageOcId(ocId: latestOcId)
            store.setWidgetFeedLastImageDate(date: nil)
            
            let title = latest.date.formatted(date: .abbreviated, time: .shortened)
            let action = Global.WidgetAction.viewImage.rawValue
            let url = URL(string: "\(Global.shared.widgetScheme)://\(action)?ocid=\(latest.ocId)&etag=\(latest.etag)&account=\(account.account)")!
            let iconPath = store.getIconPath(latest.ocId, latest.etag)
            let previewPath = store.getPreviewPath(latest.ocId, latest.etag)
            let previewExists = store.previewExists(latest.ocId, latest.etag)

            if let entry = await getImageDataEntryForMetatada(latest, previewExists: previewExists, previewPath: previewPath, iconPath: iconPath, size: context.displaySize, showDate: configuration.showDate, title: title, url: url, account: account.account, scale: scale) {
                let data = ImageProviderData(date: .now, widgetUrl: url.description, imagePath: previewPath, imageTitle: title)
                store.setWidgetFeedLastImageData(data: data, family: familyOverride == nil ? context.family.description : familyOverride!)
                return (entry: entry, reloadAtEnd: false)
            } else {
                let entry = ImageDataEntry(date: .now, showDate: false, image: nil, title: title, url: url, message: nil)
                return (entry: entry, reloadAtEnd: false)
            }
        }

        //show next image by date
        let lastImageDate = store.getWidgetFeedLastImageDate()
        let body = getRequestBody(account.userId, lastImageDate ?? latest.date)
        
        let result = await NextcloudKit.shared.searchBodyRequestAsync(serverUrl: account.urlBase, requestBody: body, showHiddenFiles: false, account: account.account, options: options)
        
        let filtered = result.files?.map({ Metadata.init(file: $0) })
        let sorted = filtered?.sorted(by: { $0.date > $1.date }) ?? []

        var nextMetadata: Metadata? = nil
        
        if let date = lastImageDate {
            nextMetadata = sorted.first(where: { $0.date < date })
        } else {
            nextMetadata = sorted.first
        }
        
        if let metadata = nextMetadata {
            
            store.setWidgetFeedLastImageDate(date: metadata.date)
            
            let title = metadata.date.formatted(date: .abbreviated, time: .shortened)
            let action = Global.WidgetAction.viewImage.rawValue
            let url = URL(string: "\(Global.shared.widgetScheme)://\(action)?ocid=\(metadata.ocId)&etag=\(metadata.etag)&account=\(account.account)")!
            let iconPath = store.getIconPath(metadata.ocId, metadata.etag)
            let previewPath = store.getPreviewPath(metadata.ocId, metadata.etag)
            let previewExists = store.previewExists(metadata.ocId, metadata.etag)
            
            if let entry = await getImageDataEntryForMetatada(metadata, previewExists: previewExists, previewPath: previewPath, iconPath: iconPath, size: context.displaySize, showDate: configuration.showDate, title: title, url: url, account: account.account, scale: scale) {
                let data = ImageProviderData(date: .now, widgetUrl: url.description, imagePath: previewPath, imageTitle: title)
                store.setWidgetFeedLastImageData(data: data, family: familyOverride == nil ? context.family.description : familyOverride!)
                return (entry: entry, reloadAtEnd: false)
            } else {
                //have metadata, but no image. show cached or empty
                if cached != nil, let entry = await buildLastCachedEntry(data: cached!, context: context, showDate: configuration.showDate, scale: scale) {
                    return (entry: entry, reloadAtEnd: true)
                }

                let entry = ImageDataEntry(date: .now, showDate: false, image: nil, title: title, url: url, message: nil)
                return (entry: entry, reloadAtEnd: true)
            }
        } else {
            store.setWidgetFeedLastImageDate(date: nil)
            
            if cached != nil, let entry = await buildLastCachedEntry(data: cached!, context: context, showDate: configuration.showDate, scale: scale) {
                return (entry: entry, reloadAtEnd: true)
            }
            
            return (entry: getEntry(), reloadAtEnd: true)
        }
    }
    
    private func buildLastCachedEntry(data: ImageProviderData, context: Context, showDate: Bool, scale: CGFloat) async -> ImageDataEntry? {
        
        if let widgetUrl = URL(string: data.widgetUrl),
           let preview = await getImage(data.imagePath, size: context.displaySize, scale: scale) {
            let entry = ImageDataEntry(date: .now, showDate: showDate, image: preview, title: data.imageTitle, url: widgetUrl)
            return entry
        }
        
        return nil
    }
    
    private func getImageDataEntryForMetatada(_ metadata: Metadata, previewExists: Bool, previewPath: String, iconPath: String, size: CGSize, showDate: Bool, title: String, url: URL, account: String, scale: CGFloat) async -> ImageDataEntry? {
        
        var image: UIImage?
        
        if previewExists {
            image = await getImage(previewPath, size: size, scale: scale)
        } else {
            image = await downloadPreview(fileId: metadata.fileId, etag: metadata.etag, ocId: metadata.ocId, path: previewPath, iconPath: iconPath, account: account, size: size, scale: scale)
        }
        
        if image != nil {
            let entry = ImageDataEntry(date: .now, showDate: showDate, image: image, title: title, url: url, message: nil)
            return entry
        }
        
        return nil
    }
    
    private func getEntry(_ message: String? = nil) -> ImageDataEntry {
        
        let url = URL(string: Global.shared.widgetScheme + "://" + Global.WidgetAction.viewImage.rawValue)!
        
        let entry = ImageDataEntry(date: .now, showDate: false, image: nil, title: "", url: url, message: message)
        return entry
    }
    
    private func getRequestBody(_ userId: String, _ date: Date) -> String {
        
        let requestBodyRecent =
            """
            <?xml version=\"1.0\"?>
            <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:basicsearch>
                <d:select>
                    <d:prop>
                        <d:displayname/>
                        <d:getcontenttype/>
                        <d:resourcetype/>
                        <d:getcontentlength/>
                        <d:getlastmodified/>
                        <d:getetag/>
                        <id xmlns=\"http://owncloud.org/ns\"/>
                        <fileid xmlns=\"http://owncloud.org/ns\"/>
                        <size xmlns=\"http://owncloud.org/ns\"/>
                        <creation_time xmlns=\"http://nextcloud.org/ns\"/>
                        <upload_time xmlns=\"http://nextcloud.org/ns\"/>
                        <is-encrypted xmlns=\"http://nextcloud.org/ns\"/>
                        <has-preview xmlns=\"http://nextcloud.org/ns\"/>
                    </d:prop>
                </d:select>
            <d:from>
                <d:scope>
                    <d:href>%@</d:href>
                    <d:depth>infinity</d:depth>
                </d:scope>
            </d:from>
            <d:where>
                <d:and>
                    <d:like>
                        <d:prop><d:getcontenttype/></d:prop>
                        <d:literal>image/%%</d:literal>
                    </d:like>
                    <d:lt>
                        <d:prop>
                            <d:getlastmodified/>
                        </d:prop>
                        <d:literal>%@</d:literal>
                    </d:lt>
                </d:and>
            </d:where>
            <d:orderby>
                <d:order>
                    <d:prop>
                        <d:getlastmodified/>
                    </d:prop>
                    <d:descending/>
                </d:order>
            </d:orderby>
            <d:limit>
                <d:nresults>10</d:nresults>
            </d:limit>
            </d:basicsearch>
            </d:searchrequest>
            """
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        
        let lessDateString = dateFormatter.string(from: date)
        
        return String(format: requestBodyRecent, "/files/" + userId, lessDateString)
    }
    
    private func getImage(_ path: String, size: CGSize, scale: CGFloat) async -> UIImage? {
        return await ImageUtility.getImageForSize(path, size: size, scale: scale)
    }
    
    private func downloadPreview(fileId: String, etag: String, ocId: String, path: String, iconPath: String, account: String, size: CGSize, scale: CGFloat) async -> UIImage? {
        
        let options = NKRequestOptions(timeout: 30, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        let result = await NextcloudKit.shared.downloadPreviewAsync(fileId: fileId,
                                                                    etag: etag,
                                                                    account: account,
                                                                    options: options)
        
        if result.error == .success, let data = result.responseData?.data {
            ImageUtility.saveImageAtPaths(data: data, previewPath: path, iconPath: iconPath)
            return await getImage(path, size: size, scale: scale)
        }
        
        return nil
    }
    
    private func clearFeedData() {
        let store = StoreUtility()
        store.clearWidgetFeedData("")
        store.clearWidgetFeedData(WidgetFamily.systemSmall.description)
        store.clearWidgetFeedData(WidgetFamily.systemMedium.description)
        store.clearWidgetFeedData(WidgetFamily.systemLarge.description)
        store.clearWidgetFeedData(WidgetFamily.systemExtraLarge.description)
        store.setWidgetFeedLastImageOcId(ocId: nil)
        store.setWidgetFeedLastImageDate(date: nil)
    }
}

extension FeedImageProvider: NextcloudKitDelegate {
    
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


