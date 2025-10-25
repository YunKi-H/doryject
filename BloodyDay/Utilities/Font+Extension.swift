//
//  Font+Extension.swift
//  BloodyDay
//
//  Created by Yunki on 10/25/25.
//

import Foundation
import SwiftUI

extension Font {
    enum PretendardWeight {
        case regular
        case medium
        case semibold
        case bold
        
        var value: String {
            switch self {
            case .regular: return "Regular"
            case .medium: return "Medium"
            case .semibold: return "SemiBold"
            case .bold: return "Bold"
            }
        }
    }
    
    static func pretendard(_ weight: PretendardWeight, size fontSize: CGFloat) -> Font {
        let familyName = "Pretendard"
        let weightString = weight.value
        
        return Font.custom("\(familyName)-\(weightString)", size: fontSize)
    }
    
    static func pretendard(_ weight: PretendardWeight, fixedSize fontSize: CGFloat) -> Font {
        let familyName = "Pretendard"
        let weightString = weight.value
        
        return Font.custom("\(familyName)-\(weightString)", fixedSize: fontSize)
    }
}
