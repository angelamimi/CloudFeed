//
//  Strings.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/17/23.
//

import Foundation

public struct Strings {}

extension Strings {
    
    //Common
    public static let OkAction = NSLocalizedString("Ok.Action", comment: "")
    public static let CancelAction = NSLocalizedString("Cancel.Action", comment: "")
    public static let ErrorTitle = NSLocalizedString("Error.Title", comment: "")
    
    //Settings - Application reset Dialog
    public static let ResetAction = NSLocalizedString("Reset.Action", comment: "")
    public static let ResetTitle = NSLocalizedString("Reset.Title", comment: "")
    public static let ResetMessage = NSLocalizedString("Reset.Message", comment: "")
    
    //Settings - Profile load error
    public static let ProfileErrorMessage = NSLocalizedString("Profile.Error.Message", comment: "")
    
    //Settings
    public static let SettingsNavTitle = NSLocalizedString("Settings.Nav.Title", comment: "")
    public static let SettingsSectionInformation = NSLocalizedString("Settings.Section.Information", comment: "")
    public static let SettingsSectionData = NSLocalizedString("Settings.Section.Data", comment: "")
    public static let SettingsItemAcknowledgements = NSLocalizedString("Settings.Item.Acknowledgements", comment: "")
    public static let SettingsItemClearCache = NSLocalizedString("Settings.Item.ClearCache", comment: "")
    public static let SettingsItemResetApplication = NSLocalizedString("Settings.Item.ResetApplication", comment: "")
    public static let SettingsLabelVersion = NSLocalizedString("Settings.Label.Version", comment: "")
    public static let SettingsLabelVersionUnknown = NSLocalizedString("Settings.Label.VersionUnknown", comment: "")
    public static let SettingsLabelCacheSize = NSLocalizedString("Settings.Label.CacheSize", comment: "")
    
    //Login
    public static let InitErrorMessage = NSLocalizedString("Init.Error.Message", comment: "")
    public static let UrlErrorMessage = NSLocalizedString("Url.Error.Message", comment: "")
    public static let LoginServerLabel = NSLocalizedString("Login.Server.Label", comment: "")
    public static let LoginServerButton = NSLocalizedString("Login.Server.Button", comment: "")
    public static let LoginServerTitle = NSLocalizedString("Login.Server.Title", comment: "")
    
    //Media
    public static let MediaErrorMessage = NSLocalizedString("Media.Error.Message", comment: "")
    public static let MediaEmptyTitle = NSLocalizedString("Media.Empty.Title", comment: "")
    public static let MediaEmptyDescription = NSLocalizedString("Media.Empty.Description", comment: "")
    public static let MediaNavTitle = NSLocalizedString("Media.Nav.Title", comment: "")
    
    //Favorites
    public static let FavErrorMessage = NSLocalizedString("Fav.Error.Message", comment: "")
    public static let FavUpdateErrorMessage = NSLocalizedString("Fav.Update.Error.Message", comment: "")
    public static let FavAdd = NSLocalizedString("Fav.Add", comment: "")
    public static let FavRemove = NSLocalizedString("Fav.Remove", comment: "")
    public static let FavEmptyTitle = NSLocalizedString("Fav.Empty.Title", comment: "")
    public static let FavEmptyDescription = NSLocalizedString("Fav.Empty.Description", comment: "")
    public static let FavNavTitle = NSLocalizedString("Fav.Nav.Title", comment: "")
    
    //Title Bar
    public static let TitleApply = NSLocalizedString("Title.ApplyChanges", comment: "")
    public static let TitleCancel = NSLocalizedString("Title.CancelChanges", comment: "")
    public static let TitleEdit = NSLocalizedString("Title.Edit", comment: "")
    public static let TitleZoomIn = NSLocalizedString("Title.ZoomIn", comment: "")
    public static let TitleZoomOut = NSLocalizedString("Title.ZoomOut", comment: "")
    
    //Image Detail and EXIF
    public static let DetailName = NSLocalizedString("Detail.Name", comment: "")
    public static let DetailEditedDate = NSLocalizedString("Detail.EditedDate", comment: "")
    public static let DetailCreatedDate = NSLocalizedString("Detail.CreatedDate", comment: "")
    public static let DetailFileSize = NSLocalizedString("Detail.FileSize", comment: "")
    public static let DetailDimensions = NSLocalizedString("Detail.Dimensions", comment: "")
    public static let DetailLenseMake = NSLocalizedString("Detail.LenseMake", comment: "")
    public static let DetailLenseModel = NSLocalizedString("Detail.LenseModel", comment: "")
    public static let DetailColorSpace = NSLocalizedString("Detail.ColorSpace", comment: "")
    public static let DetailDPI = NSLocalizedString("Detail.DPI", comment: "")
    public static let DetailProfile = NSLocalizedString("Detail.Profile", comment: "")
    public static let DetailDepth = NSLocalizedString("Detail.Depth", comment: "")
    public static let DetailAperture = NSLocalizedString("Detail.Aperture", comment: "")
    public static let DetailExposure = NSLocalizedString("Detail.Exposure", comment: "")
    public static let DetailISO = NSLocalizedString("Detail.ISO", comment: "")
    public static let DetailBrightness = NSLocalizedString("Detail.Brightness", comment: "")
}
