//
//  DelayedCapsuleLayer.swift
//  BloodyDay
//
//  Created by Yunki on 12/30/25.
//

import SwiftUI

struct DelayedCapsuleLayer: View {
    let ranges: [CalendarRangeInfo]
    let days: [DayInfo]
    let geo: GeometryProxy
    
    var body: some View {
        ForEach(ranges, id: \.self) { range in
            GlassCapsuleSegment(
                range: range.range,
                color: .mainRed10,
                height: 30,
                horizontalPadding: 1,
                days: days,
                opacity: range.opacity,
                geo: geo
            )
        }
    }
}
