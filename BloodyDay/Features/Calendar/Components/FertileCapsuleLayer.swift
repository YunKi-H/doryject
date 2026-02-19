//
//  FertileCapsuleLayer.swift
//  BloodyDay
//
//  Created by Yunki on 10/25/25.
//

import SwiftUI

struct FertileCapsuleLayer: View {
    let ranges: [DateInterval]
    let days: [DayInfo]
    let monthDate: Date
    let geo: GeometryProxy
    
    private let columns = 7
    private let rows = 6
    
    var body: some View {
        ForEach(ranges, id: \.self) { range in
            CapsuleSegment(range: range, color: .mainNeutral8, height: 30, horizontalPadding: 1, days: days, monthDate: monthDate, geo: geo)
        }
    }
}
