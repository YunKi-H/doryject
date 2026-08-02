//
//  CalendarSharingSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 7/25/26.
//

import AuthenticationServices
import SwiftUI
import UIKit

struct CalendarSharingSettingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: CalendarSharingSettingViewModel
    @State private var requestToAccept: CalendarConnectionRequest?
    @State private var connectionToDisconnect: CalendarConnection?
    @State private var isCopyToastPresented = false
    @State private var copyToastRequestID = 0

    var body: some View {
        List {
            if let user = viewModel.user {
                authenticatedContent(user)
            } else {
                signInContent
            }
        }
        .listSectionSpacing(14)
        .contentMargins(.top, 14)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.refreshSharingState()
        }
        .background {
            Color.bgPrimary
                .ignoresSafeArea()
        }
        .appGradientOverlay()
        .overlay(alignment: .bottom) {
            if isCopyToastPresented {
                copyToast
                    .padding(.bottom, 24)
                    .transition(
                        .opacity.combined(with: .move(edge: .bottom))
                    )
            }
        }
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("캘린더 연결")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.setCalendarSharingPageVisible(true)
        }
        .onDisappear {
            viewModel.setCalendarSharingPageVisible(false)
        }
        .task(id: viewModel.user?.id) {
            await viewModel.refreshSharingState()
        }
        .task(id: copyToastRequestID) {
            guard isCopyToastPresented else { return }
            try? await Task.sleep(for: .seconds(2))
            guard Task.isCancelled == false else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopyToastPresented = false
            }
        }
        .confirmationDialog(
            "사용할 캘린더를 선택해주세요",
            isPresented: acceptRequestBinding,
            titleVisibility: .visible
        ) {
            if let request = requestToAccept {
                Button("내 캘린더 사용") {
                    accept(request, useMyCalendar: true)
                }
                Button("\(request.senderDisplayName)의 캘린더 사용") {
                    accept(request, useMyCalendar: false)
                }
                Button("취소", role: .cancel) {
                    requestToAccept = nil
                }
            }
        } message: {
            Text("선택한 캘린더의 소유자만 기록을 편집할 수 있어요.")
        }
        .confirmationDialog(
            disconnectDialogTitle,
            isPresented: disconnectBinding,
            titleVisibility: .visible
        ) {
            if let connection = connectionToDisconnect,
               let user = viewModel.user {
                Button(
                    disconnectButtonTitle(connection, userID: user.id),
                    role: .destructive
                ) {
                    connectionToDisconnect = nil
                    Task {
                        await viewModel.disconnectActiveConnection()
                    }
                }
                Button("취소", role: .cancel) {
                    connectionToDisconnect = nil
                }
            }
        } message: {
            Text(disconnectDialogMessage)
        }
        .alert(
            "캘린더 연결을 처리하지 못했어요",
            isPresented: errorBinding
        ) {
            Button("확인") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var signInContent: some View {
        Section {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("둘만의 캘린더를 연결해보세요")
                        .font(.semibold_18)
                        .foregroundStyle(.textPrimary)

                    Text("Apple 계정으로 로그인하면 한 사람의 기록을 상대방과 안전하게 공유할 수 있어요.")
                        .font(.regular_16)
                        .foregroundStyle(.textSecondary40)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SignInWithAppleButton(
                    .continue,
                    onRequest: viewModel.prepareAppleSignInRequest,
                    onCompletion: { result in
                        Task {
                            await viewModel.completeAppleSignIn(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(appleButtonStyle)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(viewModel.isSigningIn)
                .overlay {
                    if viewModel.isSigningIn {
                        ProgressView()
                            .tint(colorScheme == .dark ? .black : .white)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.bgSecondary)
    }

    @ViewBuilder
    private func authenticatedContent(_ user: AuthenticatedUser) -> some View {
        if viewModel.isLoadingSharingState && viewModel.profile == nil {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .listRowBackground(Color.bgSecondary)
        } else if viewModel.isDisconnectRecoveryPending {
            pendingDisconnectSection
        } else if let connection = viewModel.activeConnection {
            connectedSection(connection, userID: user.id)
            sharedEventTypesSection(connection, userID: user.id)
        } else {
            if let profile = viewModel.profile {
                myConnectionIDSection(profile)
                sendRequestSection
            }

            if viewModel.incomingRequests.isEmpty == false {
                incomingRequestsSection
            }
        }

        Section("계정") {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName ?? "Apple 사용자")
                    .font(.regular_18)
                    .foregroundStyle(.textPrimary)

                if let email = user.email {
                    Text(email)
                        .font(.regular_14)
                        .foregroundStyle(.textSecondary40)
                }
            }

            Button("로그아웃", role: .destructive) {
                Task { await viewModel.signOut() }
            }
            .font(.regular_18)
            .foregroundStyle(.mainRed)
        }
        .listRowBackground(Color.bgSecondary)
    }

    private var pendingDisconnectSection: some View {
        Section {
            Text("서버에 남은 연결 데이터를 정리해야 해요. 정리가 끝날 때까지 새로운 캘린더를 연결할 수 없어요.")
                .font(.regular_16)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await viewModel.refreshSharingState() }
            } label: {
                HStack {
                    Spacer()
                    if viewModel.isLoadingSharingState {
                        ProgressView()
                    } else {
                        Text("연결 해제 다시 시도")
                    }
                    Spacer()
                }
            }
            .disabled(viewModel.isLoadingSharingState)
        } header: {
            Text("연결 해제")
        } footer: {
            Text(viewModel.statusMessage ?? "")
                .font(.regular_14)
        }
        .listRowBackground(Color.bgSecondary)
        .tint(.mainRed)
    }

    private func connectedSection(
        _ connection: CalendarConnection,
        userID: String
    ) -> some View {
        Section("연결된 캘린더") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(connection.partnerDisplayName(for: userID))
                        .font(.regular_18)
                        .foregroundStyle(.textPrimary)

                    Text(roleDescription(connection.role(for: userID)))
                        .font(.regular_14)
                        .foregroundStyle(.textSecondary40)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.mainRed)
            }

            Button(role: .destructive) {
                connectionToDisconnect = connection
            } label: {
                HStack {
                    if viewModel.isDisconnecting {
                        ProgressView()
                    }
                    Text(
                        connection.ownerID == userID
                            ? "캘린더 공유 중단"
                            : "캘린더 연결 나가기"
                    )
                }
            }
            .disabled(viewModel.isDisconnecting)
            .foregroundStyle(.mainRed)
        }
        .listRowBackground(Color.bgSecondary)
    }

    @ViewBuilder
    private func sharedEventTypesSection(
        _ connection: CalendarConnection,
        userID: String
    ) -> some View {
        let canEdit = connection.ownerID == userID
        Section {
            sharingTypeRow(
                title: "생리 기록",
                icon: Image(systemName: "drop.fill"),
                color: .mainRed,
                isOn: connection.sharedEventTypes.period,
                canEdit: canEdit,
                type: .period
            )
            sharingTypeRow(
                title: "피임약 기록",
                icon: Image(.pillHalf),
                color: .subBlue,
                isOn: connection.sharedEventTypes.pill,
                canEdit: canEdit,
                type: .pill
            )
            sharingTypeRow(
                title: "사랑한 날 기록",
                icon: Image(systemName: "heart.fill"),
                color: .subPink,
                isOn: connection.sharedEventTypes.love,
                canEdit: canEdit,
                type: .love
            )
        } header: {
            Text("공유 데이터")
        } footer: {
            if canEdit == false {
                Text("캘린더 소유자만 공유 항목을 변경할 수 있어요.")
                    .font(.regular_14)
            } else {
                EmptyView()
            }
        }
        .listRowBackground(Color.bgSecondary)
    }

    private func sharingTypeRow(
        title: String,
        icon: Image,
        color: Color,
        isOn: Bool,
        canEdit: Bool,
        type: EventType
    ) -> some View {
        HStack {
            icon
                .foregroundStyle(color)
                .frame(width: 22)
            Text(title)
                .font(.regular_18)
                .foregroundStyle(.textPrimary)
            Spacer()
            if canEdit {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { isOn },
                        set: { enabled in
                            Task {
                                await viewModel.setSharedEventType(
                                    type,
                                    enabled: enabled
                                )
                            }
                        }
                    )
                )
                .labelsHidden()
                .tint(color)
            } else {
                Text(isOn ? "공유 중" : "공유 안 함")
                    .font(.regular_14)
                    .foregroundStyle(.textSecondary40)
            }
        }
    }

    private func myConnectionIDSection(
        _ profile: CalendarSharingProfile
    ) -> some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("내 연결 ID")
                        .font(.regular_14)
                        .foregroundStyle(.textSecondary40)
                    Text(profile.connectionCode)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.textPrimary)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = profile.connectionCode
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCopyToastPresented = true
                    }
                    copyToastRequestID += 1
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.icon)
                }
                .buttonStyle(.plain)
            }
        } header: {
            EmptyView()
        } footer: {
            Text("상대방에게 이 ID를 알려주세요.")
                .font(.regular_14)
        }
        .listRowBackground(Color.bgSecondary)
    }

    private var copyToast: some View {
        Text("클립보드에 복사되었습니다")
            .font(.regular_14)
            .foregroundStyle(.bgPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.textPrimary, in: Capsule())
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var sendRequestSection: some View {
        Section {
            TextField("상대방 연결 ID", text: partnerCodeBinding)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onSubmit {
                    sendConnectionRequest()
                }

            Button {
                sendConnectionRequest()
            } label: {
                HStack {
                    Spacer()
                    if viewModel.isSendingRequest {
                        ProgressView()
                    } else {
                        Text("연결 요청 보내기")
                    }
                    Spacer()
                }
            }
            .disabled(
                viewModel.partnerConnectionCode.count != 8
                || viewModel.isSendingRequest
            )
        } header: {
            Text("상대방 연결")
        } footer: {
            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.regular_14)
                    .foregroundStyle(.mainRed)
            } else {
                EmptyView()
            }
        }
        .listRowBackground(Color.bgSecondary)
        .tint(.mainRed)
    }

    private var incomingRequestsSection: some View {
        Section("받은 연결 요청") {
            ForEach(viewModel.incomingRequests) { request in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(request.senderDisplayName)님이 캘린더 연결을 요청했어요.")
                        .font(.regular_16)
                        .foregroundStyle(.textPrimary)

                    HStack {
                        Button("거절", role: .destructive) {
                            Task {
                                await viewModel.decline(request)
                            }
                        }
                        Spacer()
                        Button("연결") {
                            requestToAccept = request
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mainRed)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listRowBackground(Color.bgSecondary)
    }

    private var partnerCodeBinding: Binding<String> {
        Binding(
            get: { viewModel.partnerConnectionCode },
            set: { value in
                viewModel.partnerConnectionCode = String(
                    value
                        .uppercased()
                        .filter { $0.isLetter || $0.isNumber }
                        .prefix(8)
                )
            }
        )
    }

    private var acceptRequestBinding: Binding<Bool> {
        Binding(
            get: { requestToAccept != nil },
            set: { isPresented in
                if isPresented == false {
                    requestToAccept = nil
                }
            }
        )
    }

    private var disconnectBinding: Binding<Bool> {
        Binding(
            get: { connectionToDisconnect != nil },
            set: { isPresented in
                if isPresented == false {
                    connectionToDisconnect = nil
                }
            }
        )
    }

    private var disconnectDialogTitle: String {
        guard let connection = connectionToDisconnect,
              let user = viewModel.user else {
            return "캘린더 연결을 해제할까요?"
        }
        return connection.ownerID == user.id
            ? "캘린더 공유를 중단할까요?"
            : "캘린더 연결에서 나갈까요?"
    }

    private var disconnectDialogMessage: String {
        guard let connection = connectionToDisconnect,
              let user = viewModel.user else {
            return ""
        }
        if connection.ownerID == user.id {
            return "상대방은 더 이상 이 캘린더를 볼 수 없어요. 내 기록은 기기에 그대로 유지됩니다."
        }
        return "공유받은 캘린더가 이 기기에서 제거되고 내 로컬 캘린더로 돌아갑니다."
    }

    private func disconnectButtonTitle(
        _ connection: CalendarConnection,
        userID: String
    ) -> String {
        connection.ownerID == userID ? "공유 중단" : "연결 나가기"
    }

    private var appleButtonStyle: SignInWithAppleButton.Style {
        colorScheme == .dark ? .white : .black
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    viewModel.dismissError()
                }
            }
        )
    }

    private func sendConnectionRequest() {
        guard viewModel.partnerConnectionCode.count == 8 else { return }
        Task {
            await viewModel.sendConnectionRequest()
        }
    }

    private func accept(
        _ request: CalendarConnectionRequest,
        useMyCalendar: Bool
    ) {
        requestToAccept = nil
        Task {
            await viewModel.accept(
                request,
                useMyCalendar: useMyCalendar
            )
        }
    }

    private func roleDescription(_ role: CalendarConnectionRole?) -> String {
        switch role {
        case .owner:
            return "내 캘린더를 공유 중 · 편집 가능"
        case .viewer:
            return "상대방 캘린더를 보는 중 · 읽기 전용"
        case .none:
            return "연결 상태를 확인할 수 없어요"
        }
    }
}

#Preview {
    NavigationStack {
        CalendarSharingSettingView(
            viewModel: .init(
                authenticationService: PreviewAuthenticationService(
                    currentUser: AuthenticatedUser(
                        id: "preview-user",
                        displayName: "윤기",
                        email: "yunki@example.com"
                    )
                ),
                connectionRepository: PreviewCalendarConnectionRepository()
            )
        )
    }
}
