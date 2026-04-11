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
    
    static var regular_11: Font {
        return pretendard(.regular, fixedSize: 11)
    }
    
    static var regular_14: Font {
        return pretendard(.regular, fixedSize: 14)
    }
    
    static var regular_16: Font {
        return pretendard(.regular, fixedSize: 16)
    }
    
    static var regular_18: Font {
        return pretendard(.regular, fixedSize: 18)
    }
    
    static var regular_20: Font {
        return pretendard(.regular, fixedSize: 20)
    }
    
    static var medium_9: Font {
        return pretendard(.medium, fixedSize: 9)
    }
    
    static var medium_11: Font {
        return pretendard(.medium, fixedSize: 11)
    }
    
    static var medium_14: Font {
        return pretendard(.medium, fixedSize: 14)
    }
    
    static var medium_16: Font {
        return pretendard(.medium, fixedSize: 16)
    }
    
    static var medium_18: Font {
        return pretendard(.medium, fixedSize: 18)
    }
    
    static var semibold_14: Font {
        return pretendard(.semibold, fixedSize: 14)
    }
    
    static var semibold_18: Font {
        return pretendard(.semibold, fixedSize: 18)
    }
    
    static var semibold_32: Font {
        return pretendard(.semibold, fixedSize: 32)
    }
    
    static var bold_22: Font {
        return pretendard(.bold, fixedSize: 22)
    }
}

extension Font {
    static func clarendon(size fontSize: CGFloat) -> Font {
        return Font.custom("Clarendon Bold", fixedSize: fontSize)
    }
    
    static func clarendon(fixedSize fontSize: CGFloat) -> Font {
        return Font.custom("Clarendon Bold", fixedSize: fontSize)
    }
    
    static var clarendon_16: Font {
        return Font.clarendon(fixedSize: 16)
    }
    
    static var clarendon_24: Font {
        return Font.clarendon(fixedSize: 24)
    }
    
    static var clarendon_26: Font {
        return Font.clarendon(fixedSize: 26)
    }
}
