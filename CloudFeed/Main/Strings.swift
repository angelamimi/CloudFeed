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
    
    //Login
    public static let InitErrorMessage = NSLocalizedString("Init.Error.Message", comment: "")
    public static let UrlErrorMessage = NSLocalizedString("Url.Error.Message", comment: "")
    
    //Media
    public static let MediaErrorMessage = NSLocalizedString("Media.Error.Message", comment: "")
    
    //Favorites
    public static let FavErrorMessage = NSLocalizedString("Fav.Error.Message", comment: "")
}
