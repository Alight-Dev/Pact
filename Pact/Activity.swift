//
//  Activity.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import Foundation
import SwiftData

@Model
final class Activity {
    var name: String
    var activityDescription: String
    var iconName: String
    var order: Int
    var createdAt: Date
    /// Indices of selected days: 0 = Sunday, 1 = Monday, … 6 = Saturday. Empty means no days chosen.
    var repeatDays: [Int]

    init(name: String, activityDescription: String, iconName: String, order: Int = 0, repeatDays: [Int] = []) {
        self.name = name
        self.activityDescription = activityDescription
        self.iconName = iconName
        self.order = order
        self.createdAt = Date()
        self.repeatDays = repeatDays
    }
}
