//
//  FirestoreSharingErrorClassifierTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/26/26.
//

import FirebaseFirestore
import Foundation
import Testing
@testable import BloodyDay

struct FirestoreSharingErrorClassifierTests {
    @Test
    func identifiesOnlyFirestorePermissionDeniedErrors() {
        let permissionDenied = NSError(
            domain: FirestoreErrorDomain,
            code: FirestoreErrorCode.Code.permissionDenied.rawValue
        )
        let unavailable = NSError(
            domain: FirestoreErrorDomain,
            code: FirestoreErrorCode.Code.unavailable.rawValue
        )
        let unrelated = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet
        )

        #expect(
            FirestoreSharingErrorClassifier.isPermissionDenied(
                permissionDenied
            )
        )
        #expect(
            FirestoreSharingErrorClassifier.isPermissionDenied(
                unavailable
            ) == false
        )
        #expect(
            FirestoreSharingErrorClassifier.isPermissionDenied(
                unrelated
            ) == false
        )
    }
}
