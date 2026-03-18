//
//  OvulationCapsuleLayer.swift
//  BloodyDay
//
//  Created by Yunki on 10/25/25.
//

import SwiftUI

struct OvulationCapsuleLayer: View {
    let ranges: [CalendarRangeInfo]
    let days: [DayInfo]
    let geo: GeometryProxy
    
    private let columns = 7
    private let rows = 6
    
    var body: some View {
        ForEach(ranges, id: \.self) { range in
            CapsuleSegment(
                range: range.range,
                color: .textTertiary8,
                height: 20,
                horizontalPadding: 6,
                days: days,
                opacity: range.opacity,
                geo: geo
            )
        }
    }
}
