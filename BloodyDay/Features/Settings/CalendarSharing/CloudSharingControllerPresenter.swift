//
//  CloudSharingControllerPresenter.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import CloudKit
import SwiftUI
import UIKit

struct CloudSharingControllerPresenter: UIViewControllerRepresentable {
    let existingShare: CKShare?
    let shouldPresentOnAppear: Bool
    let prepareShare: @MainActor () async throws -> CKShare
    let onDidPresent: @MainActor () -> Void
    let onDidDismiss: @MainActor () -> Void
    let onDidSaveShare: @MainActor () -> Void
    let onDidStopSharing: @MainActor () -> Void
    let onDidFailToSaveShare: @MainActor (Error) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onDidDismiss: onDidDismiss,
            onDidSaveShare: onDidSaveShare,
            onDidStopSharing: onDidStopSharing,
            onDidFailToSaveShare: onDidFailToSaveShare
        )
    }
    
    func makeUIViewController(context: Context) -> PresenterViewController {
        PresenterViewController(
            onPresentedControllerDismissed: {
                Task { @MainActor in
                    onDidDismiss()
                }
            },
            shouldPresentOnAppear: shouldPresentOnAppear,
            makeSharingController: {
                let controller: UICloudSharingController
                if let existingShare {
                    controller = UICloudSharingController(
                        share: existingShare,
                        container: CKContainer(identifier: CloudKitSharingService.containerIdentifier)
                    )
                } else {
                    controller = UICloudSharingController { _, completion in
                        Task { @MainActor in
                            do {
                                let share = try await prepareShare()
                                completion(share, CKContainer(identifier: CloudKitSharingService.containerIdentifier), nil)
                            } catch {
                                onDidFailToSaveShare(error)
                                completion(nil, nil, error)
                            }
                        }
                    }
                }
                controller.delegate = context.coordinator
                controller.presentationController?.delegate = context.coordinator
                controller.availablePermissions = [.allowPrivate, .allowReadOnly]
                return controller
            },
            onDidPresent: {
                Task { @MainActor in
                    onDidPresent()
                }
            }
        )
    }
    
    func updateUIViewController(_ uiViewController: PresenterViewController, context: Context) {}
    
    final class PresenterViewController: UIViewController {
        private let onPresentedControllerDismissed: () -> Void
        private let shouldPresentOnAppear: Bool
        private let makeSharingController: () -> UICloudSharingController
        private let onDidPresent: () -> Void
        private var didPresentSharingController = false
        
        init(
            onPresentedControllerDismissed: @escaping () -> Void,
            shouldPresentOnAppear: Bool,
            makeSharingController: @escaping () -> UICloudSharingController,
            onDidPresent: @escaping () -> Void
        ) {
            self.onPresentedControllerDismissed = onPresentedControllerDismissed
            self.shouldPresentOnAppear = shouldPresentOnAppear
            self.makeSharingController = makeSharingController
            self.onDidPresent = onDidPresent
            super.init(nibName: nil, bundle: nil)
        }
        
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            guard shouldPresentOnAppear else { return }
            
            if didPresentSharingController {
                if presentedViewController == nil {
                    onPresentedControllerDismissed()
                }
                return
            }
            
            didPresentSharingController = true
            present(makeSharingController(), animated: false) { [onDidPresent] in
                onDidPresent()
            }
        }
    }
    
    final class Coordinator: NSObject, UICloudSharingControllerDelegate, UIAdaptivePresentationControllerDelegate {
        private let onDidDismiss: @MainActor () -> Void
        private let onDidSaveShare: @MainActor () -> Void
        private let onDidStopSharing: @MainActor () -> Void
        private let onDidFailToSaveShare: @MainActor (Error) -> Void
        
        init(
            onDidDismiss: @escaping @MainActor () -> Void,
            onDidSaveShare: @escaping @MainActor () -> Void,
            onDidStopSharing: @escaping @MainActor () -> Void,
            onDidFailToSaveShare: @escaping @MainActor (Error) -> Void
        ) {
            self.onDidDismiss = onDidDismiss
            self.onDidSaveShare = onDidSaveShare
            self.onDidStopSharing = onDidStopSharing
            self.onDidFailToSaveShare = onDidFailToSaveShare
        }
        
        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: any Error
        ) {
            Task { @MainActor in
                onDidFailToSaveShare(error)
            }
        }
        
        func itemTitle(for csc: UICloudSharingController) -> String? {
            "BloodyDay 캘린더 공유"
        }
        
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            Task { @MainActor in
                onDidDismiss()
            }
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            Task { @MainActor in
                onDidSaveShare()
            }
        }
        
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            Task { @MainActor in
                onDidStopSharing()
            }
        }
    }
}
