//
//  CapsuleSegment.swift
//  BloodyDay
//
//  Created by Yunki on 10/25/25.
//

import SwiftUI

struct CapsuleSegment: View {
    let range: DateInterval
    let color: Color
    let height: CGFloat
    let horizontalPadding: CGFloat
    let days: [DayInfo]
    let geo: GeometryProxy
    
    private let columns = 7
    private let rows = 6
    
    var body: some View {
        if let startIndex = days.firstIndex(where: { $0.date == range.start }),
           let endIndex = days.firstIndex(where: { $0.date == range.end }) {
            
            let startRow = startIndex / columns
            let startCol = startIndex % columns
            let endCol = endIndex % columns
            
            let cellWidth = geo.size.width / CGFloat(columns)
            let cellHeight = geo.size.height / CGFloat(rows)
            
            let startX = CGFloat(startCol) * cellWidth + horizontalPadding
            let endX = CGFloat(endCol) * cellWidth + cellWidth - horizontalPadding
            let y = CGFloat(startRow) * cellHeight + 14
            
            Capsule()
                .fill(color)
                .frame(width: endX - startX, height: height)
                .position(x: (startX + endX) / 2, y: y)
        }
    }
}
