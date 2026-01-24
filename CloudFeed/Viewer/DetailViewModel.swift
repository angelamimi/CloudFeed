//
//  DetailViewModel.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 12/18/24.
//  Copyright © 2024 Angela Jarosz. All rights reserved.
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
protocol DetailDelegate: AnyObject {
    func detailLoaded()
}

@MainActor
final class DetailViewModel: NSObject {
    
    var mediaPath: String?
    var metadata: Metadata?
    
    weak var delegate: DetailDelegate?
    
    enum MetadataSectionId: Int {
        case general = 0
        case gps = 1
        case exif = 2
        case tiff = 3
    }
    
    var details = [MetadataSectionId: MetadataSection]()
    
    func buildDetailsDatasource() {

        guard let metadata = metadata else { return }
        
        details[.general] = MetadataSection(title: Strings.DetailSectionGeneral)
        details[.gps] = MetadataSection(title: Strings.DetailSectionGps)
        details[.exif] = MetadataSection(title: Strings.DetailSectionExif)
        details[.tiff] = MetadataSection(title: Strings.DetailSectionTiff)
        
        appendGeneralDetails(metadata: metadata)
        
        guard let path = mediaPath else { return }
        guard metadata.image else { return }
        
        let imageSourceURL = URL(fileURLWithPath: path)
        
        guard let originalSource = CGImageSourceCreateWithURL(imageSourceURL as CFURL, nil) else { return }
        guard let fileProperties = CGImageSourceCopyProperties(originalSource, nil) else { return }
        
        Task { [weak self] in
            if let detailDict = await self?.buildExif(originalSource: originalSource, fileProperties: fileProperties) {
                self?.appendData(data: detailDict)
            }
        }
    }
    
    private func buildExif(originalSource: CGImageSource, fileProperties: CFDictionary) async -> NSMutableDictionary {
        
        let details = NSMutableDictionary()
        let properties = NSMutableDictionary(dictionary: fileProperties)

        if let valFileSize = properties[kCGImagePropertyFileSize] {
            details[kCGImagePropertyFileSize] = valFileSize
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(originalSource, 0, nil) else { return details }
        let imageDict = NSMutableDictionary(dictionary: imageProperties)
        
        /*for (key, value) in imageDict {
            print("\(key) \(value)")
        }*/
        
        if let width = imageDict[kCGImagePropertyPixelWidth], let height = imageDict[kCGImagePropertyPixelHeight] {
            details[kCGImagePropertyPixelWidth] = width
            details[kCGImagePropertyPixelHeight] = height
        }
        
        if let dpiWidth = imageDict[kCGImagePropertyDPIWidth], let dpiHeight = imageDict[kCGImagePropertyDPIHeight] {
            details[kCGImagePropertyDPIWidth] = dpiWidth
            details[kCGImagePropertyDPIHeight] = dpiHeight
        }
        
        if let colorModel = imageDict[kCGImagePropertyColorModel] {
            details[kCGImagePropertyColorModel] = colorModel
        }
        
        if let depth = imageDict[kCGImagePropertyDepth] {
            details[kCGImagePropertyDepth] = depth
        }
        
        if let profile = imageDict[kCGImagePropertyProfileName] {
            details[kCGImagePropertyProfileName] = profile
        }
        
        if let orientation = imageDict[kCGImagePropertyOrientation] {
            details[kCGImagePropertyOrientation] = orientation
        }
        
        let exifAux = imageDict[kCGImagePropertyExifAuxDictionary] as? [NSString: AnyObject]
        
        if let exif = imageDict[kCGImagePropertyExifDictionary] as? [NSString: AnyObject] {
            
            if let aperture = exif[kCGImagePropertyExifApertureValue] {
                details[kCGImagePropertyExifApertureValue] = aperture
            }
            
            if let maxAperture = exif[kCGImagePropertyExifMaxApertureValue] {
                details[kCGImagePropertyExifMaxApertureValue] = maxAperture
            }
            
            if let contrast = exif[kCGImagePropertyExifContrast] {
                details[kCGImagePropertyExifContrast] = contrast
            }
            
            if let colorSpace = exif[kCGImagePropertyExifColorSpace] {
                details[kCGImagePropertyExifColorSpace] = colorSpace
            }
            
            if let customRendered = exif[kCGImagePropertyExifCustomRendered] {
                details[kCGImagePropertyExifCustomRendered] = customRendered
            }
            
            if let date = exif[kCGImagePropertyExifDateTimeOriginal] {
                details[kCGImagePropertyExifDateTimeOriginal] = date
            }
            
            if let digitalZoomRatio = exif[kCGImagePropertyExifDigitalZoomRatio] {
                details[kCGImagePropertyExifDigitalZoomRatio] = digitalZoomRatio
            }
            
            if let fileSource = exif[kCGImagePropertyExifFileSource] {
                details[kCGImagePropertyExifFileSource] = fileSource
            }
            
            if let exifVersion = exif[kCGImagePropertyExifVersion] {
                details[kCGImagePropertyExifVersion] = exifVersion
            }
            
            if exifAux != nil, let lensInfo = exifAux![kCGImagePropertyExifAuxLensInfo] {
                details[kCGImagePropertyExifAuxLensInfo] = lensInfo
            }
            
            if let lensMake = exif[kCGImagePropertyExifLensMake] {
                details[kCGImagePropertyExifLensMake] = lensMake
            }
            
            if let lensModel = exif[kCGImagePropertyExifLensModel] {
                details[kCGImagePropertyExifLensModel] = lensModel
            }
            
            if let lensSpecification = exif[kCGImagePropertyExifLensSpecification] {
                details[kCGImagePropertyExifLensSpecification] = lensSpecification
            }
            
            if let fNumber = exif[kCGImagePropertyExifFNumber] as? Double {
                details[kCGImagePropertyExifFNumber] = fNumber
            }
            
            if let exposure = exif[kCGImagePropertyExifExposureBiasValue] as? Int {
                details[kCGImagePropertyExifExposureBiasValue] = exposure
            }
            
            if let exposureMode = exif[kCGImagePropertyExifExposureMode] as? Int32 {
                details[kCGImagePropertyExifExposureMode] = exposureMode
            }
            
            if let exposureProgram = exif[kCGImagePropertyExifExposureProgram] as? Int32 {
                details[kCGImagePropertyExifExposureProgram] = exposureProgram
            }
            
            if let exposureTime = exif[kCGImagePropertyExifExposureTime] as? Double {
                details[kCGImagePropertyExifExposureTime] = exposureTime
            }
            
            if let flash = exif[kCGImagePropertyExifFlash] as? Int32 {
                details[kCGImagePropertyExifFlash] = flash
            }
            
            if let flashPixVersion = exif[kCGImagePropertyExifFlashPixVersion] {
                details[kCGImagePropertyExifFlashPixVersion] = flashPixVersion
            }
            
            if let focalLength = exif[kCGImagePropertyExifFocalLength] as? Double {
                details[kCGImagePropertyExifFocalLength] = focalLength
            }
            
            if let focalLengthIn35mmFilm = exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? Double {
                details[kCGImagePropertyExifFocalLenIn35mmFilm] = focalLengthIn35mmFilm
            }
            
            if let iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [Int])?[0] {
                details[kCGImagePropertyExifISOSpeedRatings] = iso
            }
            
            if let meteringMode = exif[kCGImagePropertyExifMeteringMode] as? Int32 {
                details[kCGImagePropertyExifMeteringMode] = meteringMode
            }
            
            if let brightness = exif[kCGImagePropertyExifBrightnessValue] as? Double {
                details[kCGImagePropertyExifBrightnessValue] = brightness
            }
            
            if let recommendedExposureIndex = exif[kCGImagePropertyExifRecommendedExposureIndex] as? Int32 {
                details[kCGImagePropertyExifRecommendedExposureIndex] = recommendedExposureIndex
            }
            
            if let saturation = exif[kCGImagePropertyExifSaturation] as? Int32 {
                details[kCGImagePropertyExifSaturation] = saturation
            }
            
            if let sceneCaptureType = exif[kCGImagePropertyExifSceneCaptureType] as? Int32 {
                details[kCGImagePropertyExifSceneCaptureType] = sceneCaptureType
            }
            
            if let sceneType = exif[kCGImagePropertyExifSceneType] as? Int32 {
                details[kCGImagePropertyExifSceneType] = sceneType
            }
            
            if let sensitivityType = exif[kCGImagePropertyExifSensitivityType] as? Int32 {
                details[kCGImagePropertyExifSensitivityType] = sensitivityType
            }
            
            if let sharpness = exif[kCGImagePropertyExifSharpness] as? Int32 {
                details[kCGImagePropertyExifSharpness] = sharpness
            }
            
            if let shutterSpeed = exif[kCGImagePropertyExifShutterSpeedValue] as? Double {
                details[kCGImagePropertyExifShutterSpeedValue] = shutterSpeed
            }
            
            if let whiteBalance = exif[kCGImagePropertyExifWhiteBalance] as? Int32 {
                details[kCGImagePropertyExifWhiteBalance] = whiteBalance
            }
        }
        
        if let gps = imageDict[kCGImagePropertyGPSDictionary] as? [NSString: AnyObject] {
            
            if let altitude = gps[kCGImagePropertyGPSAltitude] as? Double {
                details[kCGImagePropertyGPSAltitude] = altitude
            }
            
            if let altitudeReference = gps[kCGImagePropertyGPSAltitudeRef] as? Int32 {
                details[kCGImagePropertyGPSAltitudeRef] = altitudeReference
            }
            
            if let latitude = gps[kCGImagePropertyGPSLatitude] as? Double {
                details[kCGImagePropertyGPSLatitude] = latitude
            }
            
            if let longitude = gps[kCGImagePropertyGPSLongitude] as? Double {
                details[kCGImagePropertyGPSLongitude] = longitude
            }
            
            if let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String {
                details[kCGImagePropertyGPSLatitudeRef] = latitudeRef
            }
            
            if let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String {
                details[kCGImagePropertyGPSLongitudeRef] = longitudeRef
            }
            
            if let speed = gps[kCGImagePropertyGPSSpeed] as? Double {
                details[kCGImagePropertyGPSSpeed] = speed
            }
            
            if let speedRef = gps[kCGImagePropertyGPSSpeedRef] as? String {
                details[kCGImagePropertyGPSSpeedRef] = speedRef
            }
            
            if let dateStamp = gps[kCGImagePropertyGPSDateStamp] as? String {
                details[kCGImagePropertyGPSDateStamp] = dateStamp
            }
            
            if let destinationBearing = gps[kCGImagePropertyGPSDestBearing] as? Double {
                details[kCGImagePropertyGPSDestBearing] = destinationBearing
            }
            
            if let destinationBearingReference = gps[kCGImagePropertyGPSDestBearingRef] as? String {
                details[kCGImagePropertyGPSDestBearingRef] = destinationBearingReference
            }
            
            if let horizontalPositioningError = gps[kCGImagePropertyGPSHPositioningError] as? Double {
                details[kCGImagePropertyGPSHPositioningError] = horizontalPositioningError
            }
            
            if let imageDirection = gps[kCGImagePropertyGPSImgDirection] as? Double {
                details[kCGImagePropertyGPSImgDirection] = imageDirection
            }
            
            if let imageDirectionReference = gps[kCGImagePropertyGPSImgDirectionRef] as? String {
                details[kCGImagePropertyGPSImgDirectionRef] = imageDirectionReference
            }
            
            if let timeStamp = gps[kCGImagePropertyGPSTimeStamp] as? String {
                details[kCGImagePropertyGPSTimeStamp] = timeStamp
            }
        }
        
        if let tiff = imageDict[kCGImagePropertyTIFFDictionary] as? [NSString: AnyObject] {
            
            if let dateTime = tiff[kCGImagePropertyTIFFDateTime] as? String {
                details[kCGImagePropertyTIFFDateTime] = dateTime
            }
            
            if let hostComputer = tiff[kCGImagePropertyTIFFHostComputer] as? String {
                details[kCGImagePropertyTIFFHostComputer] = hostComputer
            }
            
            if let make = tiff[kCGImagePropertyTIFFMake] as? String {
                details[kCGImagePropertyTIFFMake] = make
            }
            
            if let model = tiff[kCGImagePropertyTIFFModel] as? String {
                details[kCGImagePropertyTIFFModel] = model
            }
            
            if let orientation = tiff[kCGImagePropertyTIFFOrientation] as? Int32 {
                details[String(kCGImagePropertyTIFFDictionary) + String(kCGImagePropertyTIFFOrientation)] = orientation
            }
            
            if let resolutionUnit = tiff[kCGImagePropertyTIFFResolutionUnit] as? Int32 {
                details[kCGImagePropertyTIFFResolutionUnit] = resolutionUnit
            }
            
            if let software = tiff[kCGImagePropertyTIFFSoftware] as? String {
                details[kCGImagePropertyTIFFSoftware] = software
            }
            
            if let xResolution = tiff[kCGImagePropertyTIFFXResolution] as? Int32 {
                details[kCGImagePropertyTIFFXResolution] = xResolution
            }
            
            if let yResolution = tiff[kCGImagePropertyTIFFYResolution] as? Int32 {
                details[kCGImagePropertyTIFFYResolution] = yResolution
            }
        }
        
        return details
    }
    
    private func appendGeneralDetails(metadata: Metadata) {

        details[.general]?.addDetail(title: Strings.DetailName, detail: metadata.fileNameView)
        details[.general]?.addDetail(title: Strings.DetailEditedDate, detail: metadata.date.formatted(date: .abbreviated, time: .standard))
                       
        if metadata.size > 0 {
            let sizeString = ByteCountFormatter.string(fromByteCount: metadata.size, countStyle: .file)
            details[.general]?.addDetail(title: Strings.DetailFileSize, detail: sizeString)
        }
        
        if metadata.image {
            let detail = NSMutableDictionary()
            if mediaPath == nil {
                detail[kCGImagePropertyPixelWidth] = metadata.width
                detail[kCGImagePropertyPixelHeight] = metadata.height
                
                appendData(data: detail)
            }
        }
    }
    
    private func appendData(data: NSMutableDictionary) {
        
        /*for (key, value) in data {
            print("key: \(key) value: \(value)")
        }*/
        
        if let originalDateTime = data[kCGImagePropertyExifDateTimeOriginal] as? String {
                
            let dateFormatterGet = DateFormatter()
            dateFormatterGet.dateFormat = "yyyy:MM:dd:HH:mm:ss"
            
            if let date = dateFormatterGet.date(from: originalDateTime) {
                details[.general]?.addDetail(title: Strings.DetailCreatedDate, detail: date.formatted(date: .abbreviated, time: .standard))
            }
        }
        
        if let width = data[kCGImagePropertyPixelWidth], let height = data[kCGImagePropertyPixelHeight] {
            details[.general]?.addDetail(title: Strings.DetailDimensions, detail: "\(width) x \(height)")
        }
        
        if let dpiWidth = data[kCGImagePropertyDPIWidth], let dpiHeight = data[kCGImagePropertyDPIHeight] {
            details[.general]?.addDetail(title: Strings.DetailDPI, detail: "\(dpiWidth) x \(dpiHeight)")
        }
        
        if let colorModel = data[kCGImagePropertyColorModel] {
            details[.general]?.addDetail(title: Strings.DetailColorModel, detail: colorModel as? String)
        }
        
        if let depth = data[kCGImagePropertyDepth] as? Int64 {
            details[.general]?.addDetail(title: Strings.DetailDepth, detail: "\(depth)")
        }
        
        if let profile = data[kCGImagePropertyProfileName] {
            details[.general]?.addDetail(title: Strings.DetailProfile, detail: profile as? String)
        }
        
        if let orientation = data[kCGImagePropertyOrientation] as? UInt32 {
            appendOrientation(.general, orientation)
        }
        
        if let aperture = data[kCGImagePropertyExifApertureValue] as? Double {
            details[.exif]?.addDetail(title: Strings.DetailAperture, detail: aperture.formatted(FloatingPointFormatStyle().precision(.fractionLength(0...2))))
        }
        
        if let brightness = data[kCGImagePropertyExifBrightnessValue] as? Double {
            details[.exif]?.addDetail(title: Strings.DetailBrightness, detail: String(format: "%.3f", brightness))
        }
        
        if let colorSpace = data[kCGImagePropertyExifColorSpace] as? Int32 {
            appendColorSpace(colorSpace)
        }
        
        if let contrast = data[kCGImagePropertyExifContrast] as? Int32 {
            appendContrast(contrast)
        }
        
        if let customRendered = data[kCGImagePropertyExifCustomRendered] as? Int32 {
            appendCustomRendered(customRendered)
        }

        if let digitalZoomRatio = data[kCGImagePropertyExifDigitalZoomRatio] as? Double {
            details[.exif]?.addDetail(title: Strings.DetailDigitalZoomRatio, detail: digitalZoomRatio.formatted(FloatingPointFormatStyle().precision(.fractionLength(0...3))))
        }
        
        if let exifVersion = data[kCGImagePropertyExifVersion] as? [Int32] {
            appendExifVersion(exifVersion)
        }
        
        if let exposure = data[kCGImagePropertyExifExposureBiasValue] as? Int {
            details[.exif]?.addDetail(title: Strings.DetailExposure, detail: "\(exposure.description) ev")
        }
        
        if let exposureMode = data[kCGImagePropertyExifExposureMode] as? Int32 {
            appendExposureMode(exposureMode)
        }
        
        if let exposureProgram = data[kCGImagePropertyExifExposureProgram] as? Int32 {
            appendExposureProgram(exposureProgram)
        }
        
        if let exposureTime = data[kCGImagePropertyExifExposureTime] as? Double {
            appendExposureTime(exposureTime)
        }
        
        if let fileSource = data[kCGImagePropertyExifFileSource] as? Int32 {
            appendFileSource(fileSource)
        }
        
        if let flash = data[kCGImagePropertyExifFlash] as? Int32 {
            appendFlash(flash)
        }
        
        if let flashPixVersion = data[kCGImagePropertyExifFlashPixVersion] as? [Int32] {
            appendFlashPixVersion(flashPixVersion)
        }
        
        if let fNumber = data[kCGImagePropertyExifFNumber] as? Double {
            details[.exif]?.addDetail(title: Strings.DetailFNumber, detail: "\(fNumber.description)")
        }
        
        if let focalLength = data[kCGImagePropertyExifFocalLength] as? Double {
            details[.exif]?.addDetail(title: Strings.DetailFocalLength, detail: focalLength.formatted(FloatingPointFormatStyle()))
        }
        
        if let focalLengthIn35mmFilm = data[kCGImagePropertyExifFocalLenIn35mmFilm] as? Double {
            details[.exif]?.addDetail(title: Strings.DetailFocalLengthIn35mmFilm, detail: focalLengthIn35mmFilm.formatted(FloatingPointFormatStyle()))
        }
        
        if let iso = data[kCGImagePropertyExifISOSpeedRatings] as? Int {
            details[.exif]?.addDetail(title: Strings.DetailISO, detail: iso.description)
        }
        
        if let lensInfo = data[kCGImagePropertyExifAuxLensInfo] as? [Double] {
            appendLensInfo(lensInfo)
        }
        
        if let lensMake = data[kCGImagePropertyExifLensMake] {
            details[.exif]?.addDetail(title: Strings.DetailLensMake, detail: lensMake as? String)
        }
        
        if let lensModel = data[kCGImagePropertyExifLensModel] {
            details[.exif]?.addDetail(title: Strings.DetailLensModel, detail: lensModel as? String)
        }
        
        if let lensSpecification = data[kCGImagePropertyExifLensSpecification] as? [Double] {
            appendLensSpecification(lensSpecification)
        }
        
        if let maxAperture = data[kCGImagePropertyExifMaxApertureValue] as? Double {
            //details[.exif]?.addDetail(title: Strings.DetailMaxAperture, detail: String(format: "%.3f", maxAperture))
            details[.exif]?.addDetail(title: Strings.DetailMaxAperture, detail: maxAperture.formatted(FloatingPointFormatStyle()))
        }
        
        if let meteringMode = data[kCGImagePropertyExifMeteringMode] as? Int32 {
            appendMeteringMode(meteringMode)
        }
        
        if let recommendedExposureIndex = data[kCGImagePropertyExifRecommendedExposureIndex] as? Int32 {
            details[.exif]?.addDetail(title: Strings.DetailRecommendedExposureIndex, detail: "\(recommendedExposureIndex)")
        }
        
        if let saturation = data[kCGImagePropertyExifSaturation] as? Int32 {
            appendSaturation(saturation)
        }
        
        if let sceneCaptureType = data[kCGImagePropertyExifSceneCaptureType] as? Int32 {
            appendSceneCaptureType(sceneCaptureType)
        }
        
        if let sceneType = data[kCGImagePropertyExifSceneType] as? Int32 {
            if sceneType == 1 {
                details[.exif]?.addDetail(title: Strings.DetailSceneType, detail: Strings.DetailSceneType1)
            }
        }
        
        if let sensitivityType = data[kCGImagePropertyExifSensitivityType] as? Int32 {
            appendSensitivityType(sensitivityType)
        }
        
        if let sharpness = data[kCGImagePropertyExifSharpness] as? Int32 {
            appendSharpness(sharpness)
        }
        
        if let shutterSpeed = data[kCGImagePropertyExifShutterSpeedValue] as? Double {
            appendShutterSpeed(shutterSpeed)
        }
        
        if let whiteBalance = data[kCGImagePropertyExifWhiteBalance] as? Int32 {
            appendWhiteBalance(whiteBalance)
        }
        
        if let altitude = data[kCGImagePropertyGPSAltitude] as? Double {
            appendAltitude(altitude)
        }
        
        if let altitudeReference = data[kCGImagePropertyGPSAltitudeRef] as? Int32 {
            appendAltitudeReference(altitudeReference)
        }
        
        if let dateStamp = data[kCGImagePropertyGPSDateStamp] as? String {
            appendDateStamp(dateStamp)
        }
        
        if let destinationBearing = data[kCGImagePropertyGPSDestBearing] as? Double {
            details[.gps]?.addDetail(title: Strings.DetailDestinationBearing, detail: destinationBearing.formatted(FloatingPointFormatStyle().precision(.fractionLength(0...3))))
        }
        
        if let destinationBearingReference = data[kCGImagePropertyGPSDestBearingRef] as? String {
            appendDestinationBearingReference(destinationBearingReference)
        }
        
        if let horizontalPositioningError = data[kCGImagePropertyGPSHPositioningError] as? Double {
            details[.gps]?.addDetail(title: Strings.DetailHorizontalPositioningError, detail: horizontalPositioningError.formatted(FloatingPointFormatStyle().precision(.fractionLength(0...3))))
        }
        
        if let imageDirection = data[kCGImagePropertyGPSImgDirection] as? Double {
            details[.gps]?.addDetail(title: Strings.DetailImageDirection, detail: imageDirection.formatted(FloatingPointFormatStyle().precision(.fractionLength(0...3))))
        }
        
        if let imageDirectionReference = data[kCGImagePropertyGPSImgDirectionRef] as? String {
            appendImageDirectionReference(imageDirectionReference)
        }
        
        if let latitude = data[kCGImagePropertyGPSLatitude] as? Double,
           let longitude = data[kCGImagePropertyGPSLongitude] as? Double {
            let latitudeReference = data[kCGImagePropertyGPSLatitudeRef] as? String
            let longitudeReference = data[kCGImagePropertyGPSLongitudeRef] as? String
            appendGPSCoordinates(latitude, longitude, latitudeReference, longitudeReference)
        }
        
        if let speed = data[kCGImagePropertyGPSSpeed] as? Double {
            details[.gps]?.addDetail(title: Strings.DetailSpeed, detail: speed.formatted(FloatingPointFormatStyle().precision(.fractionLength(0...2))))
        }
        
        if let speedReference = data[kCGImagePropertyGPSSpeedRef] as? String {
            appendSpeedReference(speedReference)
        }
        
        if let timeStamp = data[kCGImagePropertyGPSTimeStamp] as? String {
            details[.gps]?.addDetail(title: Strings.DetailTimeStamp, detail: "\(timeStamp) UTC")
        }
        
        if let dateTime = data[kCGImagePropertyTIFFDateTime] as? String {
            appendDateTime(dateTime)
        }
        
        if let hostComputer = data[kCGImagePropertyTIFFHostComputer] as? String {
            details[.tiff]?.addDetail(title: Strings.DetailHostComputer, detail: hostComputer)
        }
        
        if let make = data[kCGImagePropertyTIFFMake] as? String {
            details[.tiff]?.addDetail(title: Strings.DetailMake, detail: make)
        }
        
        if let model = data[kCGImagePropertyTIFFModel] as? String {
            details[.tiff]?.addDetail(title: Strings.DetailModel, detail: model)
        }
        
        if let orientation = data[String(kCGImagePropertyTIFFDictionary) + String(kCGImagePropertyTIFFOrientation)] as? UInt32 {
            appendOrientation(.tiff, orientation)
        }
        
        if let resolutionUnit = data[kCGImagePropertyTIFFResolutionUnit] as? Int32 {
            appendResolutionUnit(resolutionUnit)
        }
        
        if let software = data[kCGImagePropertyTIFFSoftware] as? String {
            details[.tiff]?.addDetail(title: Strings.DetailSoftware, detail: software)
        }
        
        if let xResolution = data[kCGImagePropertyTIFFXResolution] as? Int32 {
            details[.tiff]?.addDetail(title: Strings.DetailXResolution, detail: "\(xResolution)")
        }
        
        if let yResolution = data[kCGImagePropertyTIFFYResolution] as? Int32 {
            details[.tiff]?.addDetail(title: Strings.DetailYResolution, detail: "\(yResolution)")
        }
        
        delegate?.detailLoaded()
    }
    
    private func appendResolutionUnit(_ resolutionUnit: Int32) {
        
        let resolutionUnitDescription: String
        
        switch resolutionUnit {
        case 2: resolutionUnitDescription = Strings.DetailResolutionUnit2
        case 3: resolutionUnitDescription = Strings.DetailResolutionUnit3
        default:
            resolutionUnitDescription = ""
        }
        
        if !resolutionUnitDescription.isEmpty {
            details[.tiff]?.addDetail(title: Strings.DetailResolutionUnit, detail: resolutionUnitDescription)
        }
    }
    
    private func appendDateTime(_ dateTime: String) {
        
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "yyyy:MM:dd HH:mm:ss"
        
        if let date = dateFormatterGet.date(from: dateTime) {
            details[.tiff]?.addDetail(title: Strings.DetailTDateTime, detail: date.formatted(date: .abbreviated, time: .standard))
        }
    }
    
    private func appendImageDirectionReference(_ imageDirectionReference: String) {
        
        let imageDirectionReferenceDescription: String
        
        switch imageDirectionReference {
        case "T": imageDirectionReferenceDescription = Strings.DetailImageDirectionReferenceT
        case "M": imageDirectionReferenceDescription = Strings.DetailImageDirectionReferenceM
        default:
            imageDirectionReferenceDescription = ""
        }
        
        if !imageDirectionReferenceDescription.isEmpty {
            details[.gps]?.addDetail(title: Strings.DetailImageDirectionReference, detail: imageDirectionReferenceDescription)
        }
    }
    
    private func appendDestinationBearingReference(_ destinationBearingReference: String) {
        
        let destinationBearingReferenceDescription: String
        
        switch destinationBearingReference {
        case "T": destinationBearingReferenceDescription = Strings.DetailDestinationBearingReferenceT
        case "M": destinationBearingReferenceDescription = Strings.DetailDestinationBearingReferenceM
        default:
            destinationBearingReferenceDescription = ""
        }
        
        if !destinationBearingReferenceDescription.isEmpty {
            details[.gps]?.addDetail(title: Strings.DetailDestinationBearingReference, detail: destinationBearingReferenceDescription)
        }
    }
    
    private func appendDateStamp(_ dateStamp: String) {

        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "yyyy:MM:dd"
        
        if let date = dateFormatterGet.date(from: dateStamp) {
            details[.gps]?.addDetail(title: Strings.DetailDateStamp, detail: date.formatted(date: .abbreviated, time: .omitted))
        }
    }
    
    private func appendSpeedReference(_ speedReference: String) {
        
        let speedReferenceDescription: String
        
        switch speedReference {
        case "K": speedReferenceDescription = Strings.DetailSpeedReferenceK
        case "M": speedReferenceDescription = Strings.DetailSpeedReferenceM
        case "N": speedReferenceDescription = Strings.DetailSpeedReferenceN
        default:
            speedReferenceDescription = ""
        }
        
        if !speedReferenceDescription.isEmpty {
            details[.gps]?.addDetail(title: Strings.DetailSpeedReference, detail: speedReferenceDescription)
        }
    }
    
    private func appendAltitude(_ altitude: Double) {
        let altitudeDescription = altitude.formatted(FloatingPointFormatStyle().precision(.fractionLength(0...2)))
        let feetDescription = (altitude * 3.28084).formatted(FloatingPointFormatStyle().precision(.fractionLength(0...2)))
        
        details[.gps]?.addDetail(title: Strings.DetailAltitude, detail: "\(altitudeDescription) m (\(feetDescription) ft)")
    }
    
    private func appendAltitudeReference(_ altitudeRef: Int32?) {
        
        let altitudeReferenceDescription: String
        
        switch altitudeRef {
        case 0: altitudeReferenceDescription = Strings.DetailAltitudeReference0
        case 1: altitudeReferenceDescription = Strings.DetailAltitudeReference1
        default:
            altitudeReferenceDescription = ""
        }
        
        if !altitudeReferenceDescription.isEmpty {
            details[.gps]?.addDetail(title: Strings.DetailAltitudeReference, detail: altitudeReferenceDescription)
        }
    }
    
    private func appendGPSCoordinates(_ latitude: Double, _ longitude: Double, _ latitudeReference: String?, _ longitudeReference: String?) {
        
        var latitudeRef: String
        let latitudeDegrees = Int(latitude)
        let latitudeMinutes = Int((latitude - Double(latitudeDegrees)) * 60)
        let latitudeSeconds = ((latitude - Double(latitudeDegrees) - Double(latitudeMinutes) / 60) * 3600).formatted(FloatingPointFormatStyle().precision(.fractionLength(0...3)))
        
        if latitudeReference == nil {
            latitudeRef = latitude >= 0 ? "N" : "S"
        } else {
            latitudeRef = latitudeReference!
        }
        
        var longitudeRef: String
        let longitudeDegrees = Int(longitude)
        let longitudeMinutes = Int((longitude - Double(longitudeDegrees)) * 60)
        let longitudeSeconds = ((longitude - Double(longitudeDegrees) - Double(longitudeMinutes) / 60) * 3600).formatted(FloatingPointFormatStyle().precision(.fractionLength(0...3)))
        
        if longitudeReference == nil {
            longitudeRef = longitude >= 0 ? "E" : "W"
        } else {
            longitudeRef = longitudeReference!
        }
        
        details[.gps]?.addDetail(title: Strings.DetailLatitude, detail: "\(abs(latitudeDegrees))° \(latitudeMinutes)' \(latitudeSeconds)\" \(latitudeRef)")
        details[.gps]?.addDetail(title: Strings.DetailLongitude, detail: "\(abs(longitudeDegrees))° \(longitudeMinutes)' \(longitudeSeconds)\" \(longitudeRef)")
    }
    
    private func appendLensSpecification(_ lensSpecification:  [Double]) {
        let parts = lensSpecification.map({"\($0.formatted(FloatingPointFormatStyle()))"})
        let lensSpecificationDescription = parts.joined(separator: ", ")
        
        details[.exif]?.addDetail(title: Strings.DetailLensSpecification, detail: lensSpecificationDescription)
    }
    
    private func appendLensInfo(_ lensInfo: [Double]) {
        let parts = lensInfo.map({"\($0.formatted(FloatingPointFormatStyle()))"})
        let lensInfoDescription = parts.joined(separator: ", ")
        
        details[.exif]?.addDetail(title: Strings.DetailLensInfo, detail: lensInfoDescription)
    }
    
    private func appendWhiteBalance(_ whiteBalance: Int32) {
        
        let whiteBalanceDescription: String
        
        switch whiteBalance {
        case 0: whiteBalanceDescription = Strings.DetailWhiteBalance0
        case 1: whiteBalanceDescription = Strings.DetailWhiteBalance1
        default:
            whiteBalanceDescription = ""
        }
        
        if !whiteBalanceDescription.isEmpty {
            details[.exif]?.addDetail(title: Strings.DetailWhiteBalance, detail: whiteBalanceDescription)
        }
    }
    
    private func appendSharpness(_ sharpness: Int32) {
        
        let sharpnessDescription: String
        
        switch sharpness {
        case 0: sharpnessDescription = Strings.DetailSharpness0
        case 1: sharpnessDescription = Strings.DetailSharpness1
        case 2: sharpnessDescription = Strings.DetailSharpness2
        default:
            sharpnessDescription = ""
        }
        
        if !sharpnessDescription.isEmpty {
            details[.exif]?.addDetail(title: Strings.DetailSharpness, detail: sharpnessDescription)
        }
    }
    
    private func appendShutterSpeed(_ shutterSpeed: Double) {
        
        var result = pow(2.0, shutterSpeed)
        var formatted: String
        
        if result >= 1 {
            formatted = "1/\(String(format: "%.0f", result)) s"
        } else {
            result = round(pow(2.0, -shutterSpeed) * 10000) / 10000
            formatted = "\(String(format: "%.0f", result)) s"
        }
        
        details[.exif]?.addDetail(title: Strings.DetailShutterSpeed, detail: formatted)
    }
    
    private func appendSensitivityType(_ sensitivityType: Int32) {
        
        let sensitivityTypeDescription: String
        
        switch sensitivityType {
        case 0: sensitivityTypeDescription = Strings.DetailSensitivityType0
        case 1: sensitivityTypeDescription = Strings.DetailSensitivityType1
        case 2: sensitivityTypeDescription = Strings.DetailSensitivityType2
        case 3: sensitivityTypeDescription = Strings.DetailSensitivityType3
        case 4: sensitivityTypeDescription = Strings.DetailSensitivityType4
        case 5: sensitivityTypeDescription = Strings.DetailSensitivityType5
        case 6: sensitivityTypeDescription = Strings.DetailSensitivityType6
        case 7: sensitivityTypeDescription = Strings.DetailSensitivityType7
        default:
            sensitivityTypeDescription = ""
        }
        
        if !sensitivityTypeDescription.isEmpty {
            details[.exif]?.addDetail(title: Strings.DetailSensitivityType, detail: sensitivityTypeDescription)
        }
    }
    
    private func appendSceneCaptureType(_ sceneCaptureType: Int32) {
        
        let sceneCaptureTypeDescription: String
        
        switch sceneCaptureType {
        case 0: sceneCaptureTypeDescription = Strings.DetailSceneCaptureType0
        case 1: sceneCaptureTypeDescription = Strings.DetailSceneCaptureType1
        case 2: sceneCaptureTypeDescription = Strings.DetailSceneCaptureType2
        case 3: sceneCaptureTypeDescription = Strings.DetailSceneCaptureType3
        case 4: sceneCaptureTypeDescription = Strings.DetailSceneCaptureType4
        default:
            sceneCaptureTypeDescription = ""
        }
        
        if !sceneCaptureTypeDescription.isEmpty {
            details[.exif]?.addDetail(title: Strings.DetailSceneCaptureType, detail: sceneCaptureTypeDescription)
        }
    }
    
    private func appendSaturation(_ saturation: Int32) {
        
        let saturationDescription: String
        
        switch saturation {
        case 0: saturationDescription = Strings.DetailSaturation0
        case 1: saturationDescription = Strings.DetailSaturation1
        case 2: saturationDescription = Strings.DetailSaturation2
        default:
            saturationDescription = ""
        }
        
        if !saturationDescription.isEmpty {
            details[.exif]?.addDetail(title: Strings.DetailSaturation, detail: saturationDescription)
        }
    }
    
    private func appendMeteringMode(_ meteringMode: Int32) {
        
        let meteringModeDescription: String
        
        switch meteringMode {
        case 0: meteringModeDescription = Strings.DetailMeteringMode0
        case 1: meteringModeDescription = Strings.DetailMeteringMode1
        case 2: meteringModeDescription = Strings.DetailMeteringMode2
        case 3: meteringModeDescription = Strings.DetailMeteringMode3
        case 4: meteringModeDescription = Strings.DetailMeteringMode4
        case 5: meteringModeDescription = Strings.DetailMeteringMode5
        case 6: meteringModeDescription = Strings.DetailMeteringMode6
        default:
            meteringModeDescription = ""
        }
        
        if !meteringModeDescription.isEmpty {
            details[.exif]?.addDetail(title: Strings.DetailMeteringMode, detail: meteringModeDescription)
        }
    }
    
    private func appendFlashPixVersion(_ flashPixVersion: [Int32]) {
        
        let parts = flashPixVersion.map({"\($0)"})
        let flashPixVersionDescription = parts.joined(separator: ".")
        
        details[.exif]?.addDetail(title: Strings.DetailFlashPixVersion, detail: flashPixVersionDescription)
    }
    
    private func appendExifVersion(_ exifVersion: [Int32]) {
        
        let parts = exifVersion.map({"\($0)"})
        let versionDescription = parts.joined(separator: ".")
        
        details[.exif]?.addDetail(title: Strings.DetailExifVersion, detail: versionDescription)
    }
    
    private func appendFlash(_ flash: Int32) {
        
        let flashPrefix = Strings.DetailFlashPrefix
        let flashDescription = NSLocalizedString("\(flashPrefix)\(flash)", comment: "")
            
        if !flashDescription.isEmpty && !flashDescription.starts(with: flashPrefix)  {
            details[.exif]?.addDetail(title: Strings.DetailFlash, detail: flashDescription)
        }
    }
    
    private func appendFileSource(_ fileSource: Int32) {
        
        let fileSourceDescription: String
        
        switch fileSource {
        case 1: fileSourceDescription = Strings.DetailFileSource1
        case 2: fileSourceDescription = Strings.DetailFileSource2
        case 3: fileSourceDescription = Strings.DetailFileSource3
        default:
            fileSourceDescription = ""
        }
        
        if !fileSourceDescription.isEmpty {
            details[.exif]?.addDetail(title: Strings.DetailFileSource, detail: fileSourceDescription)
        }
    }
    
    private func appendExposureTime(_ exposureTime: Double) {
        
        guard exposureTime > 0 else { return }
        
        let exposureTimeDescription: String
        
        if exposureTime < 1 {
            exposureTimeDescription = "1/" + String(format:"%.0f", 1/exposureTime) + " s"
        } else {
            exposureTimeDescription = "\(exposureTime) s"
        }
        
        details[.exif]?.addDetail(title: Strings.DetailExposureTime, detail: exposureTimeDescription)
    }
    
    private func appendExposureProgram(_ exposureProgram: Int32) {
        
        let exposureProgramDescription: String
        
        switch exposureProgram {
        case 0: exposureProgramDescription = Strings.DetailExposureProgram0
        case 1: exposureProgramDescription = Strings.DetailExposureProgram1
        case 2: exposureProgramDescription = Strings.DetailExposureProgram2
        case 3: exposureProgramDescription = Strings.DetailExposureProgram3
        case 4: exposureProgramDescription = Strings.DetailExposureProgram4
        case 5: exposureProgramDescription = Strings.DetailExposureProgram5
        case 6: exposureProgramDescription = Strings.DetailExposureProgram6
        case 7: exposureProgramDescription = Strings.DetailExposureProgram7
        case 8: exposureProgramDescription = Strings.DetailExposureProgram8
        case 9: exposureProgramDescription = Strings.DetailExposureProgram9
        default:
            exposureProgramDescription = ""
        }
        
        if !exposureProgramDescription.isEmpty {
            details[.exif]?.addDetail(title: Strings.DetailExposureProgram, detail: exposureProgramDescription)
        }
    }
    
    private func appendExposureMode(_ exposureMode: Int32) {
        
        let exposureModeDescription: String
        
        switch exposureMode {
        case 0: exposureModeDescription = Strings.DetailExposureMode0
        case 1: exposureModeDescription = Strings.DetailExposureMode1
        case 2: exposureModeDescription = Strings.DetailExposureMode2
        default:
            exposureModeDescription = ""
        }
        
        if !exposureModeDescription.isEmpty {
            details[.exif]?.addDetail(title: Strings.DetailExposureMode, detail: exposureModeDescription)
        }
    }
    
    private func appendCustomRendered(_ customRendered: Int32) {
        
        let customRenderedDescription: String
        
        switch customRendered {
        case 0: customRenderedDescription = Strings.DetailCustomRendered0
        case 1: customRenderedDescription = Strings.DetailCustomRendered1
        default:
            customRenderedDescription = ""
        }
        
        if !customRenderedDescription.isEmpty {
            details[.exif]?.addDetail(title: Strings.DetailCustomRendered, detail: customRenderedDescription)
        }
    }
    
    private func appendContrast(_ contrast: Int32) {
        
        let contrastDescription: String
        
        switch contrast {
        case 0: contrastDescription = Strings.DetailContrast0
        case 1: contrastDescription = Strings.DetailContrast1
        case 2: contrastDescription = Strings.DetailContrast2
        default:
            contrastDescription = ""
        }
        
        if !contrastDescription.isEmpty {
            details[.exif]?.addDetail(title: Strings.DetailContrast, detail: contrastDescription)
        }
    }
    
    private func appendColorSpace(_ colorSpace: Int32) {
        
        let colorSpaceDescription: String
        
        if colorSpace == 1 {
            colorSpaceDescription = Strings.DetailColorSpaceSRGB
        } else {
            colorSpaceDescription = Strings.DetailColorSpaceOther
        }
        
        details[.exif]?.addDetail(title: Strings.DetailColorSpace, detail: colorSpaceDescription)
    }
    
    private func appendOrientation(_ section: MetadataSectionId, _ orientation: UInt32) {
        
        guard let orientationValue = CGImagePropertyOrientation(rawValue: orientation) else { return }
        
        var orientationDescription: String
        
        switch orientationValue {
        case CGImagePropertyOrientation.up: orientationDescription = Strings.DetailOrientationUp
        case CGImagePropertyOrientation.down: orientationDescription = Strings.DetailOrientationDown
        case CGImagePropertyOrientation.left: orientationDescription = Strings.DetailOrientationLeft
        case CGImagePropertyOrientation.right: orientationDescription = Strings.DetailOrientationRight
        case CGImagePropertyOrientation.upMirrored: orientationDescription = Strings.DetailOrientationUpMirrored
        case CGImagePropertyOrientation.downMirrored: orientationDescription = Strings.DetailOrientationDownMirrored
        case CGImagePropertyOrientation.leftMirrored: orientationDescription = Strings.DetailOrientationLeftMirrored
        case CGImagePropertyOrientation.rightMirrored: orientationDescription = Strings.DetailOrientationRightMirrored
        default:
            orientationDescription = ""
        }

        details[section]?.addDetail(title: Strings.DetailOrientation, detail: orientationDescription == "" ? "\(orientation)" : "\(orientationDescription)")
    }
}
