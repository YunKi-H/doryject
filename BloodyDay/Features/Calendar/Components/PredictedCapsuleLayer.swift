//
//  PredictedCapsuleLayer.swift
//  BloodyDay
//
//  Created by Yunki on 10/25/25.
//

import SwiftUI

struct PredictedCapsuleLayer: View {
    let ranges: [DateInterval]
    let days: [DayInfo]
    let geo: GeometryProxy
    
    private let columns = 7
    private let rows = 6
    
    var body: some View {
        ForEach(ranges, id: \.self) { range in
            CapsuleSegment(range: range, color: .pink.opacity(0.3), height: 30, horizontalPadding: 1, days: days, geo: geo)
        }
    }
}
