//
//  AppIntent.swift
//  BloodyDayWidget
//
//  Created by Yunki on 3/21/26.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "B-Day Widget" }
    static var description: IntentDescription { "오늘 기준 생리 상태와 요약 정보를 표시합니다." }
}
