//
//  BloodyDayTabBar.swift
//  BloodyDay
//
//  Created by Yunki on 11/5/25.
//

import SwiftUI

enum BloodyDayTab: String, CaseIterable {
    case calendar = "달력"
    case period = "주기"
    
    var symbol: String {
        switch self {
        case .calendar: return "calendar"
        case .period: return "clock"
        }
    }
    
    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

struct BloodyDayTabBar<TabItemView: View>: UIViewRepresentable {
    var size: CGSize
    var activeTint: Color = .mainRed
    var barTint: Color = Color(red: 237/255, green: 237/255, blue: 237/255)
    @Binding var activeTab: BloodyDayTab
    @ViewBuilder var tabItemView: (BloodyDayTab) -> TabItemView
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UISegmentedControl {
        let items = BloodyDayTab.allCases.map(\.rawValue)
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        
        for (index, tab) in BloodyDayTab.allCases.enumerated() {
            let renderer = ImageRenderer(content: tabItemView(tab))
            renderer.scale = 2
            let image = renderer.uiImage
            
            control.setImage(image, forSegmentAt: index)
        }
        
        DispatchQueue.main.async {
            for subview in control.subviews {
                if subview is UIImageView && subview != control.subviews.last {
                    subview.alpha = 0
                }
            }
        }
        
        control.selectedSegmentTintColor = UIColor(barTint)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor(activeTint)
        ], for: .selected)
        
        control.addTarget(context.coordinator, action: #selector(context.coordinator.tabSelected(_:)), for: .valueChanged)
        return control
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        return size
    }
    
    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        
    }
    
    class Coordinator: NSObject {
        var parent: BloodyDayTabBar
        init(parent: BloodyDayTabBar) {
            self.parent = parent
        }
        
        @objc func tabSelected(_ control: UISegmentedControl) {
            parent.activeTab = BloodyDayTab.allCases[control.selectedSegmentIndex]
        }
    }
}

#Preview {
    TestTabBar()
}
