//
//  ViewerController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 4/2/23.
//

import AVFoundation
import AVKit
import UIKit
import NextcloudKit
import SVGKit
import os.log

class ViewerController: UIViewController {
    
    @IBOutlet weak var statusImageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    var player: AVPlayer?
    var metadata: tableMetadata = tableMetadata()
    var index: Int = 0
    
    weak var pager: PagerController?
    
    private var panRecognizer: UIPanGestureRecognizer?
    private var doubleTapRecognizer: UITapGestureRecognizer?
    private var initialCenter: CGPoint = .zero
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ViewerController.self)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if DatabaseManager.shared.getMetadataLivePhoto(metadata: metadata) != nil {
            statusImageView.image = NextcloudUtility.shared.loadImage(named: "livephoto", color: .label)
            statusLabel.text = "LIVE"
        } else {
            statusImageView.image = nil
            statusLabel.text = ""
        }
        
        imageView.isUserInteractionEnabled = true
        
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(pinchGesture:)))
        
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(panGesture:)))

        doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(tapGesture:)))
        doubleTapRecognizer!.numberOfTapsRequired = 2
        
        imageView.addGestureRecognizer(pinchRecognizer)
        imageView.addGestureRecognizer(panRecognizer!)
        imageView.addGestureRecognizer(doubleTapRecognizer!)
        
        panRecognizer?.isEnabled = false
        
        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(swipeGesture:)))
        swipeUpRecognizer.direction = .up
        
        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(swipeGesture:)))
        swipeDownRecognizer.direction = .down
        
        view.addGestureRecognizer(swipeUpRecognizer)
        view.addGestureRecognizer(swipeDownRecognizer)

        if metadata.classFile == NKCommon.typeClassFile.video.rawValue || metadata.classFile == NKCommon.typeClassFile.audio.rawValue {
            loadVideo()
        } else {
            reloadImage()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Self.logger.debug("viewDidAppear() - imageView frame: \(self.imageView.frame.width), \(self.imageView.frame.height)")
        Self.logger.debug("viewDidAppear() - imageView image size: \(self.imageView.image?.size.width ?? -1), \(self.imageView.image?.size.height ?? -1)")
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        Self.logger.debug("viewDidDisappear()")
        clearImageContainer()
    }
    
    private func clearImageContainer() {
        
        self.player?.replaceCurrentItem(with: nil)
        
        //guard imageView != nil else { return }
        
        //imageView.image = nil
        //imageView.removeFromSuperview()
    }
    
    @objc private func handleSwipe(swipeGesture: UISwipeGestureRecognizer) {
        if swipeGesture.direction == .up {
            setDetailTableVisibility(visible: true)
        } else if swipeGesture.direction == .down {
            setDetailTableVisibility(visible: false)
        }
    }
    
    private func setDetailTableVisibility(visible: Bool) {
        Self.logger.debug("setDetailTableVisibility()")
        if (visible) {
            let detailViewController = UIStoryboard(name: "Viewer", bundle: nil).instantiateViewController(withIdentifier: "DetailViewController") as! DetailController
            detailViewController.metadata = metadata
            self.present(detailViewController, animated: true, completion: nil)
        }
    }
    
    @objc func handleDoubleTap(tapGesture: UITapGestureRecognizer) {
        let currentScale : CGFloat = tapGesture.view?.layer.value(forKeyPath: "transform.scale.x") as! CGFloat
        
        if currentScale == 1.0 {
            let transform = CGAffineTransformMakeScale(2, 2)
            imageView.transform = transform
            panRecognizer?.isEnabled = true
        } else {
            let transform = CGAffineTransformMakeScale(1, 1)
            imageView.transform = transform
            panRecognizer?.isEnabled = false
        }
    }
    
    @objc func handlePan(panGesture: UIPanGestureRecognizer) {
        switch panGesture.state {
        case .began:
            initialCenter = imageView.center
        case .changed:
            let translation = panGesture.translation(in: view)
            imageView.center = CGPoint(x: initialCenter.x + translation.x, y: initialCenter.y + translation.y)
        case .ended,
             .cancelled:
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.7, options: [.curveEaseInOut]) {
                self.imageView.center = self.view.center
            }
        default:
            break
        }
    }
    
    @objc func handlePinch(pinchGesture: UIPinchGestureRecognizer) {
        
        // Use the x or y scale, they should be the same for typical zooming (non-skewing)
        let currentScale : CGFloat = pinchGesture.view?.layer.value(forKeyPath: "transform.scale.x") as! CGFloat
        
        if pinchGesture.state == .began || pinchGesture.state == .changed {

            // Variables to adjust the max/min values of zoom
            let minScale: CGFloat = 1.0
            let maxScale: CGFloat = 3.0
            let zoomSpeed: CGFloat = 0.5
            
            //  Converted to Swift 5.7.1 by Swiftify v5.7.24161 - https://swiftify.com/
            var deltaScale = pinchGesture.scale

            // You need to translate the zoom to 0 (origin) so that you
            // can multiply a speed factor and then translate back to "zoomSpace" around 1
            deltaScale = ((deltaScale - 1) * zoomSpeed) + 1
            
            // Limit to min/max size (i.e maxScale = 2, current scale = 2, 2/2 = 1.0)
            //  A deltaScale is ~0.99 for decreasing or ~1.01 for increasing
            //  A deltaScale of 1.0 will maintain the zoom size
            deltaScale = min(deltaScale, maxScale / currentScale)
            deltaScale = max(deltaScale, minScale / currentScale)

            let transform = (pinchGesture.view?.transform.scaledBy(x: deltaScale, y: deltaScale))!
      
            pinchGesture.view?.transform = transform
            pinchGesture.scale = 1.0
            
        } else if pinchGesture.state == .ended {
            
            if currentScale == 1.0 {
                panRecognizer?.isEnabled = false
            } else {
                panRecognizer?.isEnabled = true
            }
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func loadVideo() {
        let urlVideo = getVideoURL(metadata: metadata)
        
        if let url = urlVideo {
            loadVideoFromUrl(url, autoPlay: false)
        }
    }
    
    func getVideoURL(metadata: tableMetadata) -> URL? {
        
        if StoreUtility.fileProviderStorageExists(metadata) {
            return URL(fileURLWithPath: StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        } else {
            guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            return HTTPCache.shared.getProxyURL(stringURL: stringURL)
        }
    }
    
    func playLivePhoto(_ url: URL) {
        loadVideoFromUrl(url, autoPlay: true)
    }
    
    func loadVideoFromUrl(_ url: URL, autoPlay: Bool) {
        player = AVPlayer(url: url)
        let avpController = AVPlayerViewController()
        avpController.player = player
        avpController.view.backgroundColor = UIColor.systemBackground
        
        //avpController.view.frame.size.height = imageView.frame.height
        //avpController.view.frame.size.width = imageView.frame.width
        
        avpController.view.frame.size.height = self.view.frame.height
        avpController.view.frame.size.width = self.view.frame.width
        
        avpController.videoGravity = .resizeAspect
        
        avpController.showsPlaybackControls = true
        
        //Self.logger.debug("loadImage() - child count: \(self.children.count) subview count: \(self.view.subviews.count)")
        
        if self.children.count == 0 {
            addChild(avpController)
        }
        
        //TitleView, Live photo image and label container
        if self.view.subviews.count == 2 {
            self.view.addSubview(avpController.view)
        }
        
        avpController.didMove(toParent: self)
        
        if autoPlay {
            avpController.player?.play()
        }
    }
    
    func reloadImage() {
        if let metadata = DatabaseManager.shared.getMetadataFromOcId(metadata.ocId) {
            self.metadata = metadata
            loadImage(metadata: metadata)
        }
    }
    
    func loadImage(metadata: tableMetadata) {
        
        //Self.logger.debug("loadImage() - fileNameView: \(metadata.fileNameView) livePhoto? \(metadata.livePhoto)")
        
        // Download image
        if !StoreUtility.fileProviderStorageExists(metadata) && metadata.classFile == NKCommon.typeClassFile.image.rawValue {
            
            if metadata.livePhoto {
                let fileName = (metadata.fileNameView as NSString).deletingPathExtension + ".mov"
                if let metadata = DatabaseManager.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", metadata.account, metadata.serverUrl, fileName)), !StoreUtility.fileProviderStorageExists(metadata) {
                    NextcloudService.shared.download(metadata: metadata, selector: "") { _, _ in }
                }
            }
            
            NextcloudService.shared.download(metadata: metadata, selector: "") { _, _ in
                let image = getImageMetadata(metadata)
                if self.metadata.ocId == metadata.ocId && self.imageView.layer.sublayers?.count == nil {
                    //self.image = image
                    self.imageView.image = image
                }
            }
        }
        
        // Get image
        let image = getImageMetadata(metadata)
        if self.metadata.ocId == metadata.ocId && self.imageView.layer.sublayers?.count == nil {
            //self.image = image
            self.imageView.image = image
        }
        
        //self.pager?.navigationItem.title = metadata.fileNameView
        //self.title = metadata.fileNameView
        
        func getImageMetadata(_ metadata: tableMetadata) -> UIImage? {
            
            if let image = getImage(metadata: metadata) {
                return image
            }
            
            if metadata.classFile == NKCommon.typeClassFile.video.rawValue && !metadata.hasPreview {
                NextcloudUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
            }
            
            if StoreUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
                let imagePreviewPath = StoreUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
                return UIImage(contentsOfFile: imagePreviewPath)
            }
            
            /*if metadata.classFile == NKCommon.typeClassFile.video.rawValue {
                return UIImage(named: "noPreviewVideo")?.image(color: .gray, size: view.frame.width)
            } else if metadata.classFile == NKCommon.typeClassFile.audio.rawValue {
                return UIImage(named: "noPreviewAudio")?.image(color: .gray, size: view.frame.width)
            } else {
                return UIImage(named: "noPreview")?.image(color: .gray, size: view.frame.width)
            }*/
            return nil
        }
    }
    
    func getImage(metadata: tableMetadata) -> UIImage? {
        
        let ext = StoreUtility.getExtension(metadata.fileNameView)
        var image: UIImage?
        
        if StoreUtility.fileProviderStorageExists(metadata) && metadata.classFile == NKCommon.typeClassFile.image.rawValue {
            
            let previewPath = StoreUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
            let imagePath = StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            
            if ext == "GIF" {
                if !FileManager().fileExists(atPath: previewPath) {
                    NextcloudUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
                }
                
                if let fileData = FileManager().contents(atPath: imagePath) {
                    image = UIImage.gifImageWithData(fileData)
                } else {
                    image = UIImage(contentsOfFile: imagePath)
                }
            } else if ext == "SVG" {
                
                return NextcloudUtility.shared.downloadSVGPreview(metadata: metadata)
                
            } else {
                NextcloudUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
                image = UIImage(contentsOfFile: imagePath)
                
                let imageWidth : CGFloat = image?.size.width ?? 0
                let imageHeight : CGFloat = image?.size.height ?? 0
                
                if image != nil && (imageWidth > self.view.frame.width || imageHeight > self.view.frame.height) {
                    
                    //TODO: Large images spike memory. Have to downsample in some way.
                    let filePath = StoreUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                    let fileData = FileManager().contents(atPath: filePath)
                    
                    if fileData != nil {
                        var newSize : CGSize?
                        if imageWidth > imageHeight {
                            newSize = CGSize(width: self.view.frame.width, height: self.view.frame.width)
                        } else {
                            newSize = CGSize(width: self.view.frame.height, height: self.view.frame.height)
                        }
                        //Self.logger.debug("downsample!!!!!!!!!!")
                        return UIImage.downsample(imageData: (fileData! as CFData), to: newSize!)
                    }
                }
                    
                return image
            }
        }
        
        return image
    }
}
