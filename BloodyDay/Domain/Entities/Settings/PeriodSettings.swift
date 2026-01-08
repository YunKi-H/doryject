//
//  PeriodSettings.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

struct PeriodSettings: Codable {
    var autoCyclePredictionEnabled: Bool = true
    var averageCycleDays: Int? = nil
    var averagePeriodDays: Int? = nil
}
