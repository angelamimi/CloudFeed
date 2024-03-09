//
//  ImageDownloadOperation.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 3/2/24.
//

import UIKit
import os.log

class ImageDownloadOperation: AsyncOperation {
    
    private let url: URL
    private let completionHandler: ((UIImage?) -> Void)?

    private var task: Task<Void, Never>?
    private var metadataId: String?
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: ImageDownloadOperation.self))
    
    init(_ id: String, url: URL, completionHandler: ((UIImage?) -> Void)? = nil) {
        self.metadataId = id
        self.url = url
        self.completionHandler = completionHandler
    }

    override func main() {
        
        Self.logger.debug("ImageDownloadOperation() - creating task for id: \(self.metadataId!)")
        
        task = Task { [weak self] in
            
            Self.logger.debug("ImageDownloadOperation() - begin for id: \(self?.metadataId! ?? "")")
            
            guard let self = self else {
                Self.logger.debug("ImageDownloadOperation() - invalid. not going to download.")
                return
            }
            
            if isCancelled {
                Self.logger.debug("ImageDownloadOperation() - cancelled. not going to download. id: \(self.metadataId!)")
                self.completionHandler?(nil)
                return
            }
            
            Self.logger.debug("ImageDownloadOperation() - downloading id: \(self.metadataId!)")
            
            //let (data, _) = try await URLSession.shared.data(from: url)
            //sleep(5)
            
            guard let data = try? await URLSession.shared.data(from: url) else {
                Self.logger.debug("ImageDownloadOperation() - error downloading id: \(self.metadataId!) cancelled? \(self.isCancelled)")
                self.completionHandler?(nil)
                self.finish()
                return
            }

            Self.logger.debug("ImageDownloadOperation() - download complete. id: \(self.metadataId!)")
            
            if isCancelled {
                Self.logger.debug("ImageDownloadOperation() - cancelled. not converting to image. id: \(self.metadataId!)")
                self.completionHandler?(nil)
            } else {
                Self.logger.debug("ImageDownloadOperation() - converting to image. id: \(self.metadataId!)")
                let image = UIImage(data: data.0)
                Self.logger.debug("ImageDownloadOperation() - converting to image complete. id: \(self.metadataId!)")
                self.completionHandler?(image)
                self.finish()
            }
        }
    }
    
    override func cancel() {
        super.cancel()
        Self.logger.debug("ImageDownloadOperation() - cancelling id: \(self.metadataId!)  isExecuting: \(self.isExecuting) isReady: \(self.isReady)")
        task?.cancel()
        task = nil
    }
}


