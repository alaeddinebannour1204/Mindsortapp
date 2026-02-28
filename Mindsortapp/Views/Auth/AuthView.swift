//
//  AuthView.swift
//  Mindsortapp
//
//  Sign In / Sign Up screen with email and password.
//

import SwiftUI

struct AuthView: View {
    @Environment(AppStore.self) private var store
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    private var isValidEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private var canSubmit: Bool {
        isValidEmail && password.count >= 6 && !isLoading
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                Spacer(minLength: Theme.Spacing.xxl)

                VStack(spacing: Theme.Spacing.sm) {
                    Text("MindSort")
                        .font(Theme.Typography.h1())
                        .foregroundStyle(Theme.Colors.text)

                    Text("Speak naturally. Your thoughts sort themselves.")
                        .font(Theme.Typography.bodySmall())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.md) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.Colors.border, lineWidth: 1)
                        )

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.Colors.border, lineWidth: 1)
                        )

                    Button {
                        submit()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .font(Theme.Typography.h3())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.md)
                        .background(canSubmit ? Theme.Colors.accent : Theme.Colors.textTertiary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canSubmit)

                    Button {
                        isSignUp.toggle()
                        errorMessage = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(Theme.Typography.bodySmall())
                            .foregroundStyle(Theme.Colors.accent)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                Spacer(minLength: Theme.Spacing.xxl)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.background)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = errorMessage {
                Text(msg)
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                if isSignUp {
                    try await authService.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                } else {
                    try await authService.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                }
                if let uid = await authService.currentUserId() {
                    store.hydrate(userId: uid)
                }
            } catch let err as AuthError {
                errorMessage = err.errorDescription
                showError = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

#Preview {
    AuthView(authService: AuthService(url: URL(string: "https://example.supabase.co")!, key: "demo"))
        .environment(AppStore())
}
