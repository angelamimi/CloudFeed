//
//  Strings.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/17/23.
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

import Foundation

public struct Strings {}

extension Strings {
    
    //Common
    public static let OkAction = NSLocalizedString("Ok.Action", comment: "")
    public static let CancelAction = NSLocalizedString("Cancel.Action", comment: "")
    public static let DeleteAction = NSLocalizedString("Delete.Action", comment: "")
    public static let RetryAction = NSLocalizedString("Retry.Action", comment: "")
    public static let SelectAction = NSLocalizedString("Select.Action", comment: "")
    public static let ErrorTitle = NSLocalizedString("Error.Title", comment: "")
    public static let YesAction = NSLocalizedString("Yes.Action", comment: "")
    public static let NoAction = NSLocalizedString("No.Action", comment: "")
    public static let BackAction = NSLocalizedString("Back.Action", comment: "")
    public static let LiveTitle = NSLocalizedString("Live.Title", comment: "")
    public static let SwitchValueOn = NSLocalizedString("Switch.Value.On", comment: "")
    public static let SwitchValueOff = NSLocalizedString("Switch.Value.Off", comment: "")
    
    //Settings - Application reset Dialog
    public static let ResetAction = NSLocalizedString("Reset.Action", comment: "")
    public static let ResetTitle = NSLocalizedString("Reset.Title", comment: "")
    public static let ResetMessage = NSLocalizedString("Reset.Message", comment: "")
    
    //Settings - Profile load error
    public static let ProfileErrorMessage = NSLocalizedString("Profile.Error.Message", comment: "")
    
    //Settings
    public static let SettingsNavTitle = NSLocalizedString("Settings.Nav.Title", comment: "")
    public static let SettingsSectionPrivacy = NSLocalizedString("Settings.Section.Privacy", comment: "")
    public static let SettingsSectionInformation = NSLocalizedString("Settings.Section.Information", comment: "")
    public static let SettingsSectionData = NSLocalizedString("Settings.Section.Data", comment: "")
    public static let SettingsSectionDisplay = NSLocalizedString("Settings.Section.Display", comment: "")
    public static let SettingsSectionDisplayMode = NSLocalizedString("Settings.Section.DisplayMode", comment: "")
    public static let SettingsItemAddPasscode = NSLocalizedString("Settings.Item.Passcode.Add", comment: "")
    public static let SettingsItemEditPasscode = NSLocalizedString("Settings.Item.Passcode.Edit", comment: "")
    public static let SettingsItemDeletePasscode = NSLocalizedString("Settings.Item.Passcode.Delete", comment: "")
    public static let SettingsItemSettingsPasscode = NSLocalizedString("Settings.Item.Passcode.Settings", comment: "")
    public static let SettingsItemResetAppPasscode = NSLocalizedString("Settings.Item.Passcode.ResetApp", comment: "")
    public static let SettingsItemResetAppDescriptionPasscode = NSLocalizedString("Settings.Item.Passcode.ResetAppDescription", comment: "")
    public static let SettingsItemAppearance = NSLocalizedString("Settings.Item.Appearance", comment: "")
    public static let SettingsItemAcknowledgements = NSLocalizedString("Settings.Item.Acknowledgements", comment: "")
    public static let SettingsItemClearCache = NSLocalizedString("Settings.Item.ClearCache", comment: "")
    public static let SettingsItemResetApplication = NSLocalizedString("Settings.Item.ResetApplication", comment: "")
    public static let SettingsItemSystemStyle = NSLocalizedString("Settings.Label.SystemStyle", comment: "")
    public static let SettingsLabelVersion = NSLocalizedString("Settings.Label.Version", comment: "")
    public static let SettingsLabelVersionUnknown = NSLocalizedString("Settings.Label.VersionUnknown", comment: "")
    public static let SettingsLabelCacheSize = NSLocalizedString("Settings.Label.CacheSize", comment: "")
    public static let SettingsLabelDark = NSLocalizedString("Settings.Label.Dark", comment: "")
    public static let SettingsLabelLight = NSLocalizedString("Settings.Label.Light", comment: "")
    public static let SettingsLabelFolder = NSLocalizedString("Settings.Label.Folder", comment: "")
    public static let SettingsLabelFolders = NSLocalizedString("Settings.Label.Folders", comment: "")
    public static let SettingsLabelNextcloud = NSLocalizedString("Settings.Label.Nextcloud", comment: "")
    public static let SettingsLabelMediaPath = NSLocalizedString("Settings.Label.MediaPath", comment: "")
    public static let SettingsMenuAddAccount = NSLocalizedString("Settings.Menu.AddAccount", comment: "")
    
    //Profile
    public static let ProfileNavTitle = NSLocalizedString("Profile.Nav.Title", comment: "")
    public static let ProfileNavTitleView = NSLocalizedString("Profile.Nav.Title.View", comment: "")
    public static let ProfileNavTitleManage = NSLocalizedString("Profile.Nav.Title.Manage", comment: "")
    public static let ProfileItemName = NSLocalizedString("Profile.Item.Name", comment: "")
    public static let ProfileItemEmail = NSLocalizedString("Profile.Item.Email", comment: "")
    public static let ProfileItemRemoveAccount = NSLocalizedString("Profile.Item.RemoveAccount", comment: "")
    public static let ProfileRemoveTitle = NSLocalizedString("Profile.Remove.Title", comment: "")
    public static let ProfileRemoveMessage = NSLocalizedString("Profile.Remove.Message", comment: "")
    public static let ProfileRemoveAction = NSLocalizedString("Profile.Remove.Action", comment: "")
    
    //Initialization and Login
    public static let InitErrorMessage = NSLocalizedString("Init.Error.Message", comment: "")
    public static let UrlErrorMessage = NSLocalizedString("Url.Error.Message", comment: "")
    public static let MaintenanceErrorMessage = NSLocalizedString("Maintenance.Error.Message", comment: "")
    public static let LoginUnsupportedVersionErrorMessage = NSLocalizedString("Login.UnsupportedVersion.Error.Message", comment: "")
    public static let LoginServerConnectionErrorMessage = NSLocalizedString("Login.ServerConnection.Error.Message", comment: "")
    public static let LoginServerLabel = NSLocalizedString("Login.Server.Label", comment: "")
    public static let LoginServerButton = NSLocalizedString("Login.Server.Button", comment: "")
    public static let LoginServerTitle = NSLocalizedString("Login.Server.Title", comment: "")
    public static let LoginPoll = NSLocalizedString("Login.Poll", comment: "")
    public static let LoginViewCertificate = NSLocalizedString("Login.ViewCertificate", comment: "")
    public static let LoginUntrustedServer = NSLocalizedString("Login.UntrustedServer", comment: "")
    public static let LoginUntrustedServerContinue = NSLocalizedString("Login.UntrustedServerContinue", comment: "")
    public static let LoginViewCertificateError = NSLocalizedString("Login.ViewCertificateError", comment: "")
    public static let LoginUntrustedServerChanged = NSLocalizedString("Login.UntrustedServerChanged", comment: "")
    
    //Media
    public static let MediaErrorMessage = NSLocalizedString("Media.Error.Message", comment: "")
    public static let MediaEmptyTitle = NSLocalizedString("Media.Empty.Title", comment: "")
    public static let MediaEmptyDescription = NSLocalizedString("Media.Empty.Description", comment: "")
    public static let MediaEmptyFilterTitle = NSLocalizedString("Media.Empty.Filter.Title", comment: "")
    public static let MediaEmptyFilterDescription = NSLocalizedString("Media.Empty.Filter.Description", comment: "")
    public static let MediaNavTitle = NSLocalizedString("Media.Nav.Title", comment: "")
    public static let MediaFilter = NSLocalizedString("Media.Filter", comment: "")
    public static let MediaRemoveFilter = NSLocalizedString("Media.RemoveFilter", comment: "")
    public static let MediaFilterSectionDates = NSLocalizedString("Media.Filter.Section.Dates", comment: "")
    public static let MediaFilterSectionPresets = NSLocalizedString("Media.Filter.Section.Presets", comment: "")
    public static let MediaInvalidFilter = NSLocalizedString("Media.InvalidFilter", comment: "")
    public static let MediaVideoErrorMessage = NSLocalizedString("Media.Video.Error.Message", comment: "")
    public static let MediaPhoto = NSLocalizedString("Media.Photo", comment: "")
    public static let MediaLivePhoto = NSLocalizedString("Media.LivePhoto", comment: "")
    public static let MediaVideo = NSLocalizedString("Media.Video", comment: "")
    
    //Favorites
    public static let FavErrorMessage = NSLocalizedString("Fav.Error.Message", comment: "")
    public static let FavUpdateErrorMessage = NSLocalizedString("Fav.Update.Error.Message", comment: "")
    public static let FavAdd = NSLocalizedString("Fav.Add", comment: "")
    public static let FavRemove = NSLocalizedString("Fav.Remove", comment: "")
    public static let FavEmptyTitle = NSLocalizedString("Fav.Empty.Title", comment: "")
    public static let FavEmptyDescription = NSLocalizedString("Fav.Empty.Description", comment: "")
    public static let FavEmptyFilterTitle = NSLocalizedString("Fav.Empty.Filter.Title", comment: "")
    public static let FavEmptyFilterDescription = NSLocalizedString("Fav.Empty.Filter.Description", comment: "")
    public static let FavNavTitle = NSLocalizedString("Fav.Nav.Title", comment: "")
    
    //Title Bar
    public static let TitleApply = NSLocalizedString("Title.ApplyChanges", comment: "")
    public static let TitleCancel = NSLocalizedString("Title.CancelChanges", comment: "")
    public static let TitleEdit = NSLocalizedString("Title.Edit", comment: "")
    public static let TitleZoomIn = NSLocalizedString("Title.ZoomIn", comment: "")
    public static let TitleZoomOut = NSLocalizedString("Title.ZoomOut", comment: "")
    public static let TitleFilter = NSLocalizedString("Title.Filter", comment: "")
    public static let TitleSquareGrid = NSLocalizedString("Title.SquareGrid", comment: "")
    public static let TitleAspectRatioGrid = NSLocalizedString("Title.AspectRatioGrid", comment: "")
    public static let TitleAllItems = NSLocalizedString("Title.AllItems", comment: "")
    public static let TitleVideosOnly = NSLocalizedString("Title.VideosOnly", comment: "")
    public static let TitleImagesOnly = NSLocalizedString("Title.ImagesOnly", comment: "")
    public static let TitleMenu = NSLocalizedString("Title.Menu", comment: "")
    public static let TitleMediaFolder = NSLocalizedString("Title.MediaFolder", comment: "")
    
    //Sharing
    public static let ShareAction = NSLocalizedString("Share.Action", comment: "")
    public static let ShareMessageDownloading = NSLocalizedString("Share.Message.Downloading", comment: "")
    public static let ShareMessageCancel = NSLocalizedString("Share.Message.Cancel", comment: "")
    
    //Viewer
    public static let ViewerLabelImage = NSLocalizedString("Viewer.Label.Image", comment: "")
    public static let ViewerLabelVideo = NSLocalizedString("Viewer.Label.Video", comment: "")
    public static let ViewerLabelLivePhoto = NSLocalizedString("Viewer.Label.LivePhoto", comment: "")
    
    //Filter
    public static let FilterLabelDateFrom = NSLocalizedString("Filter.Label.DateFrom", comment: "")
    public static let FilterLabelDateTo = NSLocalizedString("Filter.Label.DateTo", comment: "")
    
    //Controls Speed
    public static let ControlsSpeedRate025 = NSLocalizedString("Controls.SpeedRate.0.25", comment: "")
    public static let ControlsSpeedRate05 = NSLocalizedString("Controls.SpeedRate.0.5", comment: "")
    public static let ControlsSpeedRate075 = NSLocalizedString("Controls.SpeedRate.0.75", comment: "")
    public static let ControlsSpeedRate1 = NSLocalizedString("Controls.SpeedRate.1", comment: "")
    public static let ControlsSpeedRate125 = NSLocalizedString("Controls.SpeedRate.1.25", comment: "")
    public static let ControlsSpeedRate15 = NSLocalizedString("Controls.SpeedRate.1.5", comment: "")
    public static let ControlsSpeedRate175 = NSLocalizedString("Controls.SpeedRate.1.75", comment: "")
    public static let ControlsSpeedRate2 = NSLocalizedString("Controls.SpeedRate.2", comment: "")
    public static let ControlsSpeedRateTitle = NSLocalizedString("Controls.SpeedRate.Title", comment: "")
    
    //Passcode
    public static let PasscodeNumberPad0 = NSLocalizedString("Passcode.NumberPad.0", comment: "")
    public static let PasscodeNumberPad1 = NSLocalizedString("Passcode.NumberPad.1", comment: "")
    public static let PasscodeNumberPad2 = NSLocalizedString("Passcode.NumberPad.2", comment: "")
    public static let PasscodeNumberPad3 = NSLocalizedString("Passcode.NumberPad.3", comment: "")
    public static let PasscodeNumberPad4 = NSLocalizedString("Passcode.NumberPad.4", comment: "")
    public static let PasscodeNumberPad5 = NSLocalizedString("Passcode.NumberPad.5", comment: "")
    public static let PasscodeNumberPad6 = NSLocalizedString("Passcode.NumberPad.6", comment: "")
    public static let PasscodeNumberPad7 = NSLocalizedString("Passcode.NumberPad.7", comment: "")
    public static let PasscodeNumberPad8 = NSLocalizedString("Passcode.NumberPad.8", comment: "")
    public static let PasscodeNumberPad9 = NSLocalizedString("Passcode.NumberPad.9", comment: "")
    public static let PasscodeEnter = NSLocalizedString("Passcode.Enter", comment: "")
    public static let PasscodeCreate = NSLocalizedString("Passcode.Create", comment: "")
    public static let PasscodeValidate = NSLocalizedString("Passcode.Validate", comment: "")
    public static let PasscodeSaved = NSLocalizedString("Passcode.Saved", comment: "")
    public static let PasscodeDeleted = NSLocalizedString("Passcode.Deleted", comment: "")
    
    //Image Detail and EXIF
    public static let DetailTitle = NSLocalizedString("Detail.Title", comment: "")
    public static let DetailSectionGeneral = NSLocalizedString("Detail.Section.General", comment: "")
    public static let DetailSectionGps = NSLocalizedString("Detail.Section.Gps", comment: "")
    public static let DetailSectionExif = NSLocalizedString("Detail.Section.Exif", comment: "")
    public static let DetailSectionTiff = NSLocalizedString("Detail.Section.Tiff", comment: "")
    public static let DetailAll = NSLocalizedString("Detail.All", comment: "")
    public static let DetailName = NSLocalizedString("Detail.Name", comment: "")
    public static let DetailFileDate = NSLocalizedString("Detail.FileDate", comment: "")
    public static let DetailFileFormat = NSLocalizedString("Detail.FileFormat", comment: "")
    public static let DetailVideoTypeLive = NSLocalizedString("Detail.VideoType.LivePhoto", comment: "")
    public static let DetailVideoTypeVideo = NSLocalizedString("Detail.VideoType.Video", comment: "")
    public static let DetailCameraDescription = NSLocalizedString("Detail.CameraDescription", comment: "")
    public static let DetailSizeDescription = NSLocalizedString("Detail.SizeDescription", comment: "")
    public static let DetailLensDescription = NSLocalizedString("Detail.LensDescription", comment: "")
    public static let DetailEditedDate = NSLocalizedString("Detail.EditedDate", comment: "")
    public static let DetailCreatedDate = NSLocalizedString("Detail.CreatedDate", comment: "")
    public static let DetailFileSize = NSLocalizedString("Detail.FileSize", comment: "")
    public static let DetailDimensions = NSLocalizedString("Detail.Dimensions", comment: "")
    public static let DetailLensMake = NSLocalizedString("Detail.LensMake", comment: "")
    public static let DetailLensModel = NSLocalizedString("Detail.LensModel", comment: "")
    public static let DetailColorModel = NSLocalizedString("Detail.ColorModel", comment: "")
    public static let DetailDPI = NSLocalizedString("Detail.DPI", comment: "")
    public static let DetailProfile = NSLocalizedString("Detail.Profile", comment: "")
    public static let DetailDepth = NSLocalizedString("Detail.Depth", comment: "")
    public static let DetailAperture = NSLocalizedString("Detail.Aperture", comment: "")
    public static let DetailMaxAperture = NSLocalizedString("Detail.MaxAperture", comment: "")
    public static let DetailFNumber = NSLocalizedString("Detail.FNumber", comment: "")
    public static let DetailExposure = NSLocalizedString("Detail.Exposure", comment: "")
    public static let DetailISO = NSLocalizedString("Detail.ISO", comment: "")
    public static let DetailBrightness = NSLocalizedString("Detail.Brightness", comment: "")
    public static let DetailShutterSpeed = NSLocalizedString("Detail.ShutterSpeed", comment: "")
    public static let DetailVideoSpeed = NSLocalizedString("Detail.VideoSpeed", comment: "")
    public static let DetailVideoLength = NSLocalizedString("Detail.VideoLength", comment: "")
    
    public static let DetailOrientation = NSLocalizedString("Detail.Orientation", comment: "")
    public static let DetailOrientationUp = NSLocalizedString("Detail.Orientation.Up", comment: "")
    public static let DetailOrientationUpMirrored = NSLocalizedString("Detail.Orientation.UpMirrored", comment: "")
    public static let DetailOrientationDown = NSLocalizedString("Detail.Orientation.Down", comment: "")
    public static let DetailOrientationDownMirrored = NSLocalizedString("Detail.Orientation.DownMirrored", comment: "")
    public static let DetailOrientationLeftMirrored = NSLocalizedString("Detail.Orientation.LeftMirrored", comment: "")
    public static let DetailOrientationRight = NSLocalizedString("Detail.Orientation.Right", comment: "")
    public static let DetailOrientationRightMirrored = NSLocalizedString("Detail.Orientation.RightMirrored", comment: "")
    public static let DetailOrientationLeft = NSLocalizedString("Detail.Orientation.Left", comment: "")
    
    public static let DetailColorSpace = NSLocalizedString("Detail.ColorSpace", comment: "")
    public static let DetailColorSpaceSRGB = NSLocalizedString("Detail.ColorSpace.sRGB", comment: "")
    public static let DetailColorSpaceOther = NSLocalizedString("Detail.ColorSpace.Other", comment: "")
    
    public static let DetailContrast = NSLocalizedString("Detail.Contrast", comment: "")
    public static let DetailContrast0 = NSLocalizedString("Detail.Contrast.0", comment: "")
    public static let DetailContrast1 = NSLocalizedString("Detail.Contrast.1", comment: "")
    public static let DetailContrast2 = NSLocalizedString("Detail.Contrast.2", comment: "")
    
    public static let DetailCustomRendered = NSLocalizedString("Detail.CustomRendered", comment: "")
    public static let DetailCustomRendered0 = NSLocalizedString("Detail.CustomRendered.0", comment: "")
    public static let DetailCustomRendered1 = NSLocalizedString("Detail.CustomRendered.1", comment: "")
    
    public static let DetailExposureMode = NSLocalizedString("Detail.ExposureMode", comment: "")
    public static let DetailExposureMode0 = NSLocalizedString("Detail.ExposureMode.0", comment: "")
    public static let DetailExposureMode1 = NSLocalizedString("Detail.ExposureMode.1", comment: "")
    public static let DetailExposureMode2 = NSLocalizedString("Detail.ExposureMode.2", comment: "")
    
    public static let DetailExposureProgram = NSLocalizedString("Detail.ExposureProgram", comment: "")
    public static let DetailExposureProgram0 = NSLocalizedString("Detail.ExposureProgram.0", comment: "")
    public static let DetailExposureProgram1 = NSLocalizedString("Detail.ExposureProgram.1", comment: "")
    public static let DetailExposureProgram2 = NSLocalizedString("Detail.ExposureProgram.2", comment: "")
    public static let DetailExposureProgram3 = NSLocalizedString("Detail.ExposureProgram.3", comment: "")
    public static let DetailExposureProgram4 = NSLocalizedString("Detail.ExposureProgram.4", comment: "")
    public static let DetailExposureProgram5 = NSLocalizedString("Detail.ExposureProgram.5", comment: "")
    public static let DetailExposureProgram6 = NSLocalizedString("Detail.ExposureProgram.6", comment: "")
    public static let DetailExposureProgram7 = NSLocalizedString("Detail.ExposureProgram.7", comment: "")
    public static let DetailExposureProgram8 = NSLocalizedString("Detail.ExposureProgram.8", comment: "")
    public static let DetailExposureProgram9 = NSLocalizedString("Detail.ExposureProgram.9", comment: "")
    
    public static let DetailExposureTime = NSLocalizedString("Detail.ExposureTime", comment: "")
    
    public static let DetailFileSource = NSLocalizedString("Detail.FileSource", comment: "")
    public static let DetailFileSource1 = NSLocalizedString("Detail.FileSource.1", comment: "")
    public static let DetailFileSource2 = NSLocalizedString("Detail.FileSource.2", comment: "")
    public static let DetailFileSource3 = NSLocalizedString("Detail.FileSource.3", comment: "")
    
    public static let DetailFlash = NSLocalizedString("Detail.Flash", comment: "")
    public static let DetailFlashPrefix = "Detail.Flash."
    public static let DetailFlashPixVersion = NSLocalizedString("Detail.FlashPixVersion", comment: "")
    public static let DetailDigitalZoomRatio = NSLocalizedString("Detail.DigitalZoomRatio", comment: "")
    public static let DetailExifVersion = NSLocalizedString("Detail.ExifVersion", comment: "")
    public static let DetailFocalLength = NSLocalizedString("Detail.FocalLength", comment: "")
    public static let DetailFocalLengthIn35mmFilm = NSLocalizedString("Detail.FocalLengthIn35mmFilm", comment: "")
    
    public static let DetailMeteringMode = NSLocalizedString("Detail.MeteringMode", comment: "")
    public static let DetailMeteringMode0 = NSLocalizedString("Detail.MeteringMode.0", comment: "")
    public static let DetailMeteringMode1 = NSLocalizedString("Detail.MeteringMode.1", comment: "")
    public static let DetailMeteringMode2 = NSLocalizedString("Detail.MeteringMode.2", comment: "")
    public static let DetailMeteringMode3 = NSLocalizedString("Detail.MeteringMode.3", comment: "")
    public static let DetailMeteringMode4 = NSLocalizedString("Detail.MeteringMode.4", comment: "")
    public static let DetailMeteringMode5 = NSLocalizedString("Detail.MeteringMode.5", comment: "")
    public static let DetailMeteringMode6 = NSLocalizedString("Detail.MeteringMode.6", comment: "")
    
    public static let DetailRecommendedExposureIndex = NSLocalizedString("Detail.RecommendedExposureIndex", comment: "")
    
    public static let DetailSaturation = NSLocalizedString("Detail.Saturation", comment: "")
    public static let DetailSaturation0 = NSLocalizedString("Detail.Saturation.0", comment: "")
    public static let DetailSaturation1 = NSLocalizedString("Detail.Saturation.1", comment: "")
    public static let DetailSaturation2 = NSLocalizedString("Detail.Saturation.2", comment: "")
    
    public static let DetailSceneCaptureType = NSLocalizedString("Detail.SceneCaptureType", comment: "")
    public static let DetailSceneCaptureType0 = NSLocalizedString("Detail.SceneCaptureType.0", comment: "")
    public static let DetailSceneCaptureType1 = NSLocalizedString("Detail.SceneCaptureType.1", comment: "")
    public static let DetailSceneCaptureType2 = NSLocalizedString("Detail.SceneCaptureType.2", comment: "")
    public static let DetailSceneCaptureType3 = NSLocalizedString("Detail.SceneCaptureType.3", comment: "")
    public static let DetailSceneCaptureType4 = NSLocalizedString("Detail.SceneCaptureType.4", comment: "")
    
    public static let DetailSceneType = NSLocalizedString("Detail.SceneType", comment: "")
    public static let DetailSceneType1 = NSLocalizedString("Detail.SceneType.1", comment: "")
    
    public static let DetailSensitivityType = NSLocalizedString("Detail.SensitivityType", comment: "")
    public static let DetailSensitivityType0 = NSLocalizedString("Detail.SensitivityType.0", comment: "")
    public static let DetailSensitivityType1 = NSLocalizedString("Detail.SensitivityType.1", comment: "")
    public static let DetailSensitivityType2 = NSLocalizedString("Detail.SensitivityType.2", comment: "")
    public static let DetailSensitivityType3 = NSLocalizedString("Detail.SensitivityType.3", comment: "")
    public static let DetailSensitivityType4 = NSLocalizedString("Detail.SensitivityType.4", comment: "")
    public static let DetailSensitivityType5 = NSLocalizedString("Detail.SensitivityType.5", comment: "")
    public static let DetailSensitivityType6 = NSLocalizedString("Detail.SensitivityType.6", comment: "")
    public static let DetailSensitivityType7 = NSLocalizedString("Detail.SensitivityType.7", comment: "")
    
    public static let DetailSharpness = NSLocalizedString("Detail.Sharpness", comment: "")
    public static let DetailSharpness0 = NSLocalizedString("Detail.Sharpness.0", comment: "")
    public static let DetailSharpness1 = NSLocalizedString("Detail.Sharpness.1", comment: "")
    public static let DetailSharpness2 = NSLocalizedString("Detail.Sharpness.2", comment: "")
    
    public static let DetailWhiteBalance = NSLocalizedString("Detail.WhiteBalance", comment: "")
    public static let DetailWhiteBalance0 = NSLocalizedString("Detail.WhiteBalance.0", comment: "")
    public static let DetailWhiteBalance1 = NSLocalizedString("Detail.WhiteBalance.1", comment: "")
    
    public static let DetailLensInfo = NSLocalizedString("Detail.LensInfo", comment: "")
    public static let DetailLensSpecification = NSLocalizedString("Detail.LensSpecification", comment: "")
    
    public static let DetailLatitude = NSLocalizedString("Detail.Latitude", comment: "")
    public static let DetailLongitude = NSLocalizedString("Detail.Longitude", comment: "")
    
    public static let DetailAltitude = NSLocalizedString("Detail.Altitude", comment: "")
    public static let DetailAltitudeReference = NSLocalizedString("Detail.AltitudeReference", comment: "")
    public static let DetailAltitudeReference0 = NSLocalizedString("Detail.AltitudeReference.0", comment: "")
    public static let DetailAltitudeReference1 = NSLocalizedString("Detail.AltitudeReference.1", comment: "")
    
    public static let DetailSpeed = NSLocalizedString("Detail.Speed", comment: "")
    public static let DetailSpeedReference = NSLocalizedString("Detail.SpeedReference", comment: "")
    public static let DetailSpeedReferenceK = NSLocalizedString("Detail.SpeedReference.K", comment: "")
    public static let DetailSpeedReferenceM = NSLocalizedString("Detail.SpeedReference.M", comment: "")
    public static let DetailSpeedReferenceN = NSLocalizedString("Detail.SpeedReference.N", comment: "")
    
    public static let DetailDateStamp = NSLocalizedString("Detail.DateStamp", comment: "")
    
    public static let DetailDestinationBearing = NSLocalizedString("Detail.DestinationBearing", comment: "")
    public static let DetailDestinationBearingReference = NSLocalizedString("Detail.DestinationBearingReference", comment: "")
    public static let DetailDestinationBearingReferenceM = NSLocalizedString("Detail.DestinationBearingReference.M", comment: "")
    public static let DetailDestinationBearingReferenceT = NSLocalizedString("Detail.DestinationBearingReference.T", comment: "")
    
    public static let DetailHorizontalPositioningError = NSLocalizedString("Detail.HorizontalPositioningError", comment: "")
    
    public static let DetailImageDirection = NSLocalizedString("Detail.ImageDirection", comment: "")
    public static let DetailImageDirectionReference = NSLocalizedString("Detail.ImageDirectionReference", comment: "")
    public static let DetailImageDirectionReferenceM = NSLocalizedString("Detail.ImageDirectionReference.M", comment: "")
    public static let DetailImageDirectionReferenceT = NSLocalizedString("Detail.ImageDirectionReference.T", comment: "")
    
    public static let DetailTimeStamp = NSLocalizedString("Detail.TimeStamp", comment: "")
    
    public static let DetailTDateTime = NSLocalizedString("Detail.DateTime", comment: "")
    public static let DetailHostComputer = NSLocalizedString("Detail.HostComputer", comment: "")
    public static let DetailMake = NSLocalizedString("Detail.Make", comment: "")
    public static let DetailModel = NSLocalizedString("Detail.Model", comment: "")
    public static let DetailResolutionUnit = NSLocalizedString("Detail.ResolutionUnit", comment: "")
    public static let DetailResolutionUnit2 = NSLocalizedString("Detail.ResolutionUnit.2", comment: "")
    public static let DetailResolutionUnit3 = NSLocalizedString("Detail.ResolutionUnit.3", comment: "")
    public static let DetailSoftware = NSLocalizedString("Detail.Software", comment: "")
    public static let DetailXResolution = NSLocalizedString("Detail.XResolution", comment: "")
    public static let DetailYResolution = NSLocalizedString("Detail.YResolution", comment: "")
    
    public static let DetailNameNone = NSLocalizedString("Detail.Name.None", comment: "")
    public static let DetailDateNone = NSLocalizedString("Detail.Date.None", comment: "")
    public static let DetailCameraNone = NSLocalizedString("Detail.Camera.None", comment: "")
    public static let DetailSizeNone = NSLocalizedString("Detail.Size.None", comment: "")
    public static let DetailLensNone = NSLocalizedString("Detail.Lens.None", comment: "")
}
