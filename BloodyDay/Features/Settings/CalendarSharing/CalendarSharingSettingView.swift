//
//  CalendarSharingSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 7/25/26.
//

import AuthenticationServices
import SwiftUI

struct CalendarSharingSettingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: CalendarSharingSettingViewModel

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
        .background {
            Color.bgPrimary
                .ignoresSafeArea()
        }
        .appGradientOverlay()
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("캘린더 연결")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "로그인할 수 없어요",
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
                        .foregroundStyle(.textPrimary)
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
        Section("계정") {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName ?? "Apple 사용자")
                    .font(.regular_18)
                    .foregroundStyle(.textPrimary)

                if let email = user.email {
                    Text(email)
                        .font(.regular_14)
                        .foregroundStyle(.textPrimary)
                }
            }

            Button("로그아웃", role: .destructive) {
                viewModel.signOut()
            }
            .font(.regular_18)
            .foregroundStyle(.mainRed)
        }
        .listRowBackground(Color.bgSecondary)

        Section("캘린더 연결") {
            VStack(alignment: .leading, spacing: 8) {
                Text("로그인이 완료됐어요")
                    .font(.regular_18)
                    .foregroundStyle(.textPrimary)

                Text("다음 단계에서 내 연결 ID와 상대방 연결 요청 기능을 추가할 예정이에요.")
                    .font(.regular_14)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .listRowBackground(Color.bgSecondary)
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
}

#Preview {
    NavigationStack {
        CalendarSharingSettingView(
            viewModel: .init(
                authenticationService: PreviewAuthenticationService()
            )
        )
    }
}
