//
//  AuthView.swift
//  ParkQuestGSO
//

import SwiftUI

struct AuthView: View {
    @Environment(UserSettings.self) private var userSettings

    @State private var isLogin       = true
    @State private var email         = ""
    @State private var password      = ""
    @State private var confirmPass   = ""
    @State private var isLoading     = false
    @State private var errorMessage  = ""
    @State private var logoScale: CGFloat  = 0.5
    @State private var logoOpacity: Double = 0
    @State private var formOpacity: Double = 0

    /// Role picked on the Sign Up tab. Ignored when logging in.
    @State private var selectedRole: UserType = .explorer
    /// City Partner signups collect these.
    @State private var cityName: String  = ""
    @State private var cityState: String = ""

    @FocusState private var focusedField: Field?
    private enum Field { case email, password, confirm, cityName, cityState }

    private var isCityPartnerSignUp: Bool { !isLogin && selectedRole == .cityAdmin }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 64)
                    logoSection
                    Spacer().frame(height: 48)
                    formCard
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                logoScale   = 1
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                formOpacity = 1
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [Theme.darkGreen, Theme.primaryGreen, Theme.mossGreen],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 78, height: 78)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(.white)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)

            VStack(spacing: 4) {
                Text("Park Quest NC")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(0.5)
                Text("NORTH CAROLINA")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Form card

    private var formCard: some View {
        VStack(spacing: 20) {

            // Toggle
            HStack(spacing: 0) {
                toggleTab(label: "Log In",   active: isLogin)  { withAnimation(.spring()) { isLogin = true;  errorMessage = "" } }
                toggleTab(label: "Sign Up",  active: !isLogin) { withAnimation(.spring()) { isLogin = false; errorMessage = "" } }
            }
            .background(Color.black.opacity(0.06), in: .rect(cornerRadius: 12))

            // Role picker (sign-up only)
            if !isLogin {
                rolePicker
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Fields
            VStack(spacing: 12) {
                field(icon: "envelope.fill", placeholder: "Email", text: $email, focused: .email, keyboard: .emailAddress)
                secureField(icon: "lock.fill", placeholder: "Password", text: $password, focused: .password)
                if !isLogin {
                    secureField(icon: "lock.fill", placeholder: "Confirm Password", text: $confirmPass, focused: .confirm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if isCityPartnerSignUp {
                    field(icon: "building.2.fill", placeholder: "City name", text: $cityName, focused: .cityName)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    field(icon: "mappin.circle.fill", placeholder: "State (e.g. NC)", text: $cityState, focused: .cityState)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            // Error
            if !errorMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.red.opacity(0.85))
                .padding(.horizontal, 4)
                .transition(.opacity)
            }

            // CTA
            Button { submit() } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(Theme.darkGreen)
                    } else {
                        Text(isLogin ? "Log In" : "Create Account")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.darkGreen)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(.white, in: .rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
            .buttonStyle(PressableStyle())
            .disabled(isLoading || !isFormValid)
            .opacity(isFormValid ? 1 : 0.55)
        }
        .padding(24)
        .background(.white.opacity(0.12), in: .rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .opacity(formOpacity)
    }

    // MARK: - Sub-views

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("I'M SIGNING UP AS")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 4)
            HStack(spacing: 8) {
                roleChip(role: .explorer,  title: "Park Explorer", subtitle: "Discover parks")
                roleChip(role: .cityAdmin, title: "City Partner",  subtitle: "Manage your city")
            }
        }
    }

    private func roleChip(role: UserType, title: String, subtitle: String) -> some View {
        let active = selectedRole == role
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedRole = role
                errorMessage = ""
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: role.symbol)
                        .font(.system(size: 13, weight: .bold))
                    Text(title)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                }
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.75)
            }
            .foregroundStyle(active ? Theme.darkGreen : .white)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? Color.white : .white.opacity(0.12), in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(active ? 0 : 0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func toggleTab(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(active ? Theme.darkGreen : .white.opacity(0.6))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(active ? Color.white : Color.clear, in: .rect(cornerRadius: 10))
                .padding(3)
        }
        .buttonStyle(.plain)
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, focused: Field, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 20)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .tint(.white)
                .focused($focusedField, equals: focused)
                .submitLabel(.next)
                .onSubmit { advanceFocus(from: focused) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.12), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
    }

    private func secureField(icon: String, placeholder: String, text: Binding<String>, focused: Field) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 20)
            SecureField(placeholder, text: text)
                .foregroundStyle(.white)
                .tint(.white)
                .focused($focusedField, equals: focused)
                .submitLabel(focused == .confirm || (isLogin && focused == .password) ? .done : .next)
                .onSubmit { advanceFocus(from: focused) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.12), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        let passOK  = password.count >= 6
        if isLogin { return emailOK && passOK }
        let signupBaseOK = emailOK && passOK && confirmPass == password
        if !isCityPartnerSignUp { return signupBaseOK }
        // City Partner: also require a city name + state.
        let cityOK  = !cityName.trimmingCharacters(in: .whitespaces).isEmpty
        let stateOK = cityState.trimmingCharacters(in: .whitespaces).count >= 2
        return signupBaseOK && cityOK && stateOK
    }

    // MARK: - Actions

    private func advanceFocus(from field: Field) {
        switch field {
        case .email:     focusedField = .password
        case .password:  focusedField = isLogin ? nil : .confirm
        case .confirm:   focusedField = isCityPartnerSignUp ? .cityName : nil
        case .cityName:  focusedField = .cityState
        case .cityState: focusedField = nil; submit()
        }
        if field == .confirm && !isCityPartnerSignUp { submit() }
    }

    private func submit() {
        focusedField  = nil
        errorMessage  = ""
        isLoading     = true
        Task {
            defer { isLoading = false }
            do {
                let user = isLogin
                    ? try await AuthService.shared.signIn(email: email, password: password)
                    : try await AuthService.shared.signUp(email: email, password: password)
                await MainActor.run {
                    if isCityPartnerSignUp {
                        userSettings.applyCityAdminSignUp(
                            authUser: user,
                            cityName: cityName.trimmingCharacters(in: .whitespaces),
                            state:    cityState.trimmingCharacters(in: .whitespaces).uppercased()
                        )
                    } else {
                        userSettings.applyAuthUser(user)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    AuthView()
        .environment(UserSettings())
}
