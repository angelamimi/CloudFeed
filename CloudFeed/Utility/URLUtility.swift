//
//  URLUtility.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 2/28/26.
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

final class URLUtility: NSObject {
    
    static func processActionURL(url: URL) -> (action: String, ocId: String, account: String)? {
        
        let action = url.host()
        var ocId: String? = nil
        var etag: String? = nil
        var account: String? = nil
        
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.forEach {
            ///cloudfeed://viewFavorite?ocid=&etag=&account=
            if $0.name == "ocid" && $0.value != nil {
                ocId = $0.value!
            } else if $0.name == "etag" && $0.value != nil {
                etag = $0.value!
            } else if $0.name == "account" && $0.value != nil {
                account = $0.value!
            }
        }
        
        if action != nil && ocId != nil && etag != nil && account != nil {
            if action == Global.WidgetAction.viewFavorite.rawValue
                || action == Global.WidgetAction.viewImage.rawValue {
                return (action: action!, ocId: ocId!, account: account!)
            }
        }
        
        return nil
    }
}
