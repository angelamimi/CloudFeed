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
    public static let ErrorTitle = NSLocalizedString("Error.Title", comment: "")
    public static let LiveTitle = NSLocalizedString("Live.Title", comment: "")
    
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
    
    //Initialization and Login
    public static let InitErrorMessage = NSLocalizedString("Init.Error.Message", comment: "")
    public static let UrlErrorMessage = NSLocalizedString("Url.Error.Message", comment: "")
    public static let LoginServerLabel = NSLocalizedString("Login.Server.Label", comment: "")
    public static let LoginServerButton = NSLocalizedString("Login.Server.Button", comment: "")
    public static let LoginServerTitle = NSLocalizedString("Login.Server.Title", comment: "")
    
    //Media
    public static let MediaErrorMessage = NSLocalizedString("Media.Error.Message", comment: "")
    public static let MediaEmptyTitle = NSLocalizedString("Media.Empty.Title", comment: "")
    public static let MediaEmptyDescription = NSLocalizedString("Media.Empty.Description", comment: "")
    public static let MediaEmptyFilterTitle = NSLocalizedString("Media.Empty.Filter.Title", comment: "")
    public static let MediaEmptyFilterDescription = NSLocalizedString("Media.Empty.Filter.Description", comment: "")
    public static let MediaNavTitle = NSLocalizedString("Media.Nav.Title", comment: "")
    public static let MediaFilter = NSLocalizedString("Media.Filter", comment: "")
    public static let MediaRemoveFilter = NSLocalizedString("Media.RemoveFilter", comment: "")
    public static let MediaInvalidFilter = NSLocalizedString("Media.InvalidFilter", comment: "")
    
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
    public static let DetailShutterSpeed = NSLocalizedString("Detail.ShutterSpeed", comment: "")
}
