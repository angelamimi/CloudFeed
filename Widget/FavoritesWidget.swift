//
//  FavoritesWidget.swift
//  Widget
//
//  Created by Angela Jarosz on 1/25/26.
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

import WidgetKit
import SwiftUI
import SwiftData

struct FavoritesWidgetEntryView : View {
    
    @Environment(\.widgetFamily) var widgetFamily
    
    var entry: FavoritesImageProvider.Entry

    var body: some View {
        
        ZStack {
            
            if let image = entry.image {

                if entry.showDate {
                    Rectangle()
                        .fill(.clear)
                        .layoutPriority(1)
                }
                
                if #available(iOS 18.0, *) {
                    Image(uiImage: image)
                        .resizable()
                        .widgetAccentedRenderingMode(.accentedDesaturated)
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                }
                
                if entry.showDate {
                    VStack {
                        Spacer()
                        Text(entry.title)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 1, x: 1.0, y: 1.0)
                            .padding(8)
                    }
                }
            } else {
                
                VStack {
                    
                    if widgetFamily != .systemSmall || entry.message == nil {
                        
                        if let icon = UIImage(named: "Icon") {
                            Image(uiImage: icon)
                                .resizable()
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let message = entry.message {
                        Text(message)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
        .widgetURL(entry.url)
    }
}

struct FavoritesWidget: Widget {
    let kind: String = "FavoritesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, provider: FavoritesImageProvider()) { entry in
            FavoritesWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName(LocalizedStringResource("Widget.Favorites.Config.Title"))
        .description(LocalizedStringResource("Widget.Favorites.Config.Description"))
        .supportedFamilies([.systemSmall,
                            .systemMedium,
                            .systemLarge,
                            .systemExtraLarge])
    }
}

#Preview(as: .systemSmall) {
    FavoritesWidget()
} timeline: {
    ImageDataEntry(date: .now, showDate: true, image: nil, title: "test title 1", url: URL(string: Global.shared.widgetScheme + "://")!)
    ImageDataEntry(date: .now, showDate: true, image: nil, title: "test title 2", url: URL(string: Global.shared.widgetScheme + "://")!)
    ImageDataEntry(date: .now, showDate: true, image: nil, title: "test title 3", url: URL(string: Global.shared.widgetScheme + "://")!)
}
