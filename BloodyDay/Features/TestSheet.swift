//
//  TestSheet.swift
//  BloodyDay
//
//  Created by Yunki on 11/5/25.
//

import SwiftUI

struct TestSheet: View {
    @State var trigger: Bool = true
    @State var detent: PresentationDetent = .height(80)
    var body: some View {
        VStack {
            Button {
                trigger = true
            } label: {
                Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background { Color.blue.ignoresSafeArea() }
        .sheet(isPresented: $trigger) {
            BottomSheetView(detent: $detent)
                .presentationDetents([.height(80), .height(275), .large])
                .presentationBackgroundInteraction(.enabled)
                .interactiveDismissDisabled()
        }
    }
}

struct BottomSheetView: View {
    @Binding var detent: PresentationDetent
    @State var activeTab: BloodyDayTab = .calendar
    
    var body: some View {
        GeometryReader {
            let safeArea = $0.safeAreaInsets
            let bottomPadding = safeArea.bottom / 5
            
            VStack(spacing: 0) {
                TabView(selection: $activeTab) {
                    Tab.init(value: .calendar) {
                        IndividualTabView(.calendar)
                    }
                    
                    Tab.init(value: .period) {
                        IndividualTabView(.period)
                    }
                }
                .tabViewStyle(.tabBarOnly)
                .background(TabViewHelper())
                .compositingGroup()
                
                BloodyBottomBar()
                    .padding(.bottom, bottomPadding)
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
    }
    
    @ViewBuilder
    func IndividualTabView(_ tab: BloodyDayTab) -> some View {
        ScrollView(.vertical) {
            VStack {
                HStack {
                    Spacer(minLength: 0)
                    
                    Button {
                        
                    } label: {
                        Circle()
                            .fill(.mainRed)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.title3)
                                    .fontWeight(.medium)
                            }
                    }
                    .buttonStyle(.plain)
                    .buttonBorderShape(.circle)
                }
            }
            .padding(16)
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbarBackgroundVisibility(.hidden, for: .tabBar)
    }
    
    @ViewBuilder
    func BloodyBottomBar() -> some View {
        HStack(spacing: 0) {
            ForEach(BloodyDayTab.allCases, id: \.rawValue) { tab in
                VStack(spacing: 6) {
                    Image(systemName: tab.symbol)
                        .font(.title3)
                    
                    Text(tab.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(activeTab == tab ? .mainRed : .textPrimary)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .onTapGesture {
                    activeTab = tab
                }
            }
        }
        .padding(.init(top: 10, leading: 12, bottom: 12, trailing: 12))
    }
}

#Preview {
    TestSheet()
}

fileprivate struct TabViewHelper: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        DispatchQueue.main.async {
            guard let compostingGroup = view.superview?.superview else { return }
            guard let swiftUIWrapperUITabView = compostingGroup.subviews.last else { return }
            
            if let tabBarController = swiftUIWrapperUITabView.subviews.first?.next as? UITabBarController {
                tabBarController.view.backgroundColor = .clear
                tabBarController.viewControllers?.forEach {
                    $0.view.backgroundColor = .clear
                }
                
                tabBarController.delegate = context.coordinator
                
                tabBarController.tabBar.removeFromSuperview()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) { }
    
    class Coordinator: NSObject, UITabBarControllerDelegate, UIViewControllerAnimatedTransitioning {
        func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
            return self
        }
        
        func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
            return .zero
        }
        
        func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
            guard let destinationView = transitionContext.view(forKey: .to) else { return }
            let containerView = transitionContext.containerView
            
            containerView.addSubview(destinationView)
            transitionContext.completeTransition(true)
        }
    }
}
