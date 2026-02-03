//
//  PeriodCapsuleLayer.swift
//  BloodyDay
//
//  Created by Yunki on 10/25/25.
//

import SwiftUI

struct PeriodCapsuleLayer: View {
    let ranges: [DateInterval]
    let predictedRanges: [DateInterval]
    let days: [DayInfo]
    let geo: GeometryProxy
    
    var body: some View {
        ForEach(ranges, id: \.self) { range in
            GlassCapsuleSegment(range: range, color: .mainRed, height: 30, horizontalPadding: 1, days: days, geo: geo)
        }
        ForEach(predictedRanges, id: \.self) { range in
            CapsuleSegment(range: range, color: .mainRed10, height: 30, horizontalPadding: 1, days: days, geo: geo)
        }
    }
}
