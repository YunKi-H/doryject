//
//  WidgetReloadService.swift
//  BloodyDay
//
//  Created by Yunki on 4/1/26.
//

import Foundation
import WidgetKit

protocol WidgetReloading {
    func reloadAll()
}

struct WidgetReloadService: WidgetReloading {
    func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
