//
//  ViewerViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/11/23.
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

import AVFoundation
import AVKit
import NextcloudKit
import UIKit

@MainActor
protocol DownloadableCoordinator: AnyObject {
    func download(_ metadata: Metadata)
}

@MainActor
final class ViewerViewModel {

    let metadata: Metadata
    let dataService: DataService
    private weak var coordinator: DownloadableCoordinator?

    init(dataService: DataService, metadata: Metadata) {
        self.metadata = metadata
        self.dataService = dataService
    }

    init(coordinator: DownloadableCoordinator, dataService: DataService, metadata: Metadata) {
        self.coordinator = coordinator
        self.metadata = metadata
        self.dataService = dataService
    }

    func isLivePhoto() async -> Bool {
        return await getMetadataLivePhoto(metadata: metadata) != nil
    }

    @concurrent func getMetadataLivePhoto(metadata: Metadata) async -> Metadata? {
        return await dataService.getMetadataLivePhoto(metadata: metadata)
    }

    @concurrent func getMetadataFromOcId(_ ocId: String) async -> Metadata? {
        return await dataService.getMetadataFromOcId(ocId)
    }

    func getVideoURL(metadata: Metadata) async -> URL? {

        if let url = await dataService.getDirectDownload(metadata: metadata) {
            return url
        }

        return nil
    }

    func previewExists(_ metadata: Metadata) -> Bool {
        return dataService.store.previewExists(metadata.ocId, metadata.etag)
    }

    func getPreviewPath(_ metadata: Metadata) -> String {
        return dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
    }

    func downloadPreview(_ metadata: Metadata) async {
        guard let account = Environment.current.currentUser?.account else { return }
        await dataService.downloadPreview(account: account, metadata: metadata)
    }

    func downloadImage(metadata: Metadata) {
        if !dataService.store.fileExists(metadata) {
            coordinator?.download(metadata)
        }
    }

    @concurrent func loadImage(account: String, metadata: Metadata) async -> UIImage? {

        if metadata.livePhoto {

            if !dataService.store.fileExists(metadata) {
                await dataService.download(account: account, metadata: metadata, progressHandler: { _, _ in })
            }

            if let videoMetadata = await getMetadataLivePhoto(metadata: metadata), !dataService.store.fileExists(videoMetadata) {
                await downloadLivePhotoVideo(account: account, metadata: videoMetadata)
            }

        } else if metadata.svg {

            if !dataService.store.fileExists(metadata) {
                await dataService.download(account: account, metadata: metadata, progressHandler: { _, _ in })
            }

            let iconPath = dataService.store.getIconPath(metadata.ocId, metadata.etag)
            let previewPath = dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
            let imagePath = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!

            await ImageUtility.loadSVG(metadata: metadata, imagePath: imagePath, iconPath: iconPath, previewPath: previewPath)

        } else if metadata.gif {

            if !dataService.store.fileExists(metadata) {
                await dataService.download(account: account, metadata: metadata, progressHandler: { _, _ in })
            }

            let imagePath = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)!

            return await ImageUtility.loadGIF(metadata: metadata, imagePath: imagePath)

        } else {

            if !dataService.store.fileExists(metadata) {
                await dataService.download(account: account, metadata: metadata, progressHandler: { _, _ in })
            }

            if dataService.iconPreviewCheck(metadata: metadata) == false {
                await dataService.savePreview(metadata: metadata)
            }
        }

        if dataService.store.fileExists(metadata), let imagePath = dataService.store.getCachePath(metadata.ocId, metadata.fileNameView) {
            return autoreleasepool { () -> UIImage? in
                return UIImage(contentsOfFile: imagePath)
            }
        }
        return nil
    }

    func saveVideoPreview(metadata: Metadata, image: UIImage) {
        Task { [weak self] in
            await self?.dataService.saveVideoPreview(metadata: metadata, image: image)
        }
    }

    func getVideoFrame(metadata: Metadata) -> UIImage? {
        return dataService.getVideoFrame(metadata: metadata)
    }

    func downloadVideoFrame(metadata: Metadata, url: URL, size: CGSize) async -> UIImage? {
        return await dataService.downloadVideoFrame(metadata: metadata, url: url, size: size)
    }

    @concurrent func downloadLivePhotoVideo(account: String, metadata: Metadata) async {
        await dataService.download(account: account, metadata: metadata, progressHandler: { _, _ in })
    }

    func getCachePath(_ metadata: Metadata) -> String? {
        if dataService.store.fileExists(metadata) {
            return dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)
        }
        return nil
    }

    func getFilePath(_ metadata: Metadata) -> String? {
        if dataService.store.fileExists(metadata) {
            return dataService.store.getCachePath(metadata.ocId, metadata.fileNameView)
        } else if dataService.store.previewExists(metadata.ocId, metadata.etag) {
            return dataService.store.getPreviewPath(metadata.ocId, metadata.etag)
        }
        return nil
    }

    func fileExists(_ metadata: Metadata) -> Bool {
        return dataService.store.fileExists(metadata)
    }

    func getVideoControlsStyleBackground() -> Bool {
        return dataService.getVideoControlsStyleBackground() ?? true
    }
}
