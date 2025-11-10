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
    
    // 원하는 내부 여백(선택 배경과 바 배경 사이 거리)
    private let innerPadding: CGFloat = 4
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    // 컨테이너 + 세그먼트 구조로 만들어 4pt 인셋을 강제
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        
        // 실제 탭 UI
        let control = UISegmentedControl(items: BloodyDayTab.allCases.map(\.rawValue))
        control.selectedSegmentIndex = activeTab.index
        
        // 각 세그먼트에 커스텀 렌더 이미지 적용
        for (index, tab) in BloodyDayTab.allCases.enumerated() {
            let renderer = ImageRenderer(content: tabItemView(tab))
            renderer.scale = 2
            let image = renderer.uiImage
            control.setImage(image, forSegmentAt: index)
        }
        
        // 불필요한 기본 타이틀 표시 제거(이미 이미지로 대체)
        DispatchQueue.main.async {
            for subview in control.subviews {
                if subview is UIImageView && subview != control.subviews.last {
                    subview.alpha = 0
                }
            }
        }
        
        // 색상/모양
        control.selectedSegmentTintColor = UIColor(barTint)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor(activeTint)
        ], for: .selected)
        
        // 모서리 둥글게(캡슐 느낌). 높이에 맞춰 충분히 크게
        control.layer.masksToBounds = true
        
        // 오토레이아웃으로 4pt 인셋
        control.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(control)
        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: innerPadding),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -innerPadding),
            control.topAnchor.constraint(equalTo: container.topAnchor, constant: innerPadding),
            control.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -innerPadding)
        ])
        
        // 코너 반경은 실제 높이가 정해진 뒤 업데이트 필요
        // updateUIView에서 size를 받아 반영
        control.addTarget(context.coordinator, action: #selector(context.coordinator.tabSelected(_:)), for: .valueChanged)
        context.coordinator.control = control
        
        return container
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        return size
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 컨테이너의 서브뷰로 control이 존재
        guard let control = context.coordinator.control else { return }
        
        // SwiftUI에서 전달한 size 기준으로 캡슐 모양 유지
        // 컨테이너에서 4pt*2 인셋이 들어가므로, 실제 control 높이는 (size.height - 8)
        let controlHeight = max(0, size.height - innerPadding * 2)
        control.layer.cornerRadius = controlHeight / 2
        
        // 선택 색/배경 색 갱신(동적 테마 대응)
        control.selectedSegmentTintColor = UIColor(barTint)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor(activeTint)
        ], for: .selected)
        
        // 선택된 탭 동기화
        if control.selectedSegmentIndex != activeTab.index {
            control.selectedSegmentIndex = activeTab.index
        }
    }
    
    class Coordinator: NSObject {
        var parent: BloodyDayTabBar
        weak var control: UISegmentedControl?
        
        init(parent: BloodyDayTabBar) {
            self.parent = parent
        }
        
        @objc func tabSelected(_ control: UISegmentedControl) {
            parent.activeTab = BloodyDayTab.allCases[control.selectedSegmentIndex]
        }
    }
}

#Preview {
    BloodyDayRootView()
}
