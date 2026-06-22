// RootView.swift — decide si mostrar onboarding, auth o la app principal
import SwiftUI
import LocalAuthentication

struct RootView: View {
    @State private var auth = AuthManager.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var deepLinkBookingId: String?
    @State private var deepLinkDisputeId: String?
    @State private var showSplash = true
    @State private var isLocked = false
    @State private var isJailbroken = false
    @Environment(\.scenePhase) private var scenePhase

    private var isUITestingAuth: Bool { CommandLine.arguments.contains("UI_TESTING_AUTH") }
    private var isUITestingLoggedIn: Bool { CommandLine.arguments.contains("UI_TESTING_LOGGED_IN") }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isUITestingAuth {
                AuthFlowView()
            } else if isUITestingLoggedIn {
                MainTabView(deepLinkBookingId: .constant(nil), deepLinkDisputeId: .constant(nil))
            } else if showSplash {
                SplashVideoView {
                    withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
                }
                .ignoresSafeArea()
                .task {
                    try? await Task.sleep(for: .seconds(8))
                    if showSplash {
                        withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
                    }
                }
            } else if auth.isAuthenticated {
                if !hasSeenOnboarding {
                    OnboardingView {
                        withAnimation { hasSeenOnboarding = true }
                    }
                } else {
                    MainTabView(deepLinkBookingId: $deepLinkBookingId, deepLinkDisputeId: $deepLinkDisputeId)
                }
            } else {
                AuthFlowView()
            }

            // Oculta contenido en el app switcher
            if auth.isAuthenticated && scenePhase != .active {
                privacyShield
            }

            // Requiere biometría al volver del background
            if isLocked && auth.isAuthenticated {
                lockScreen
            }

            // Dispositivo con jailbreak — sin salida
            if isJailbroken {
                jailbreakBlockScreen
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasSeenOnboarding)
        .onChange(of: scenePhase) { _, newPhase in
            guard auth.isAuthenticated else { return }
            if newPhase == .background {
                isLocked = true
            } else if newPhase == .active && isLocked {
                Task { await unlockWithBiometrics() }
            }
        }
        .onChange(of: auth.isAuthenticated) { _, loggedIn in
            if !loggedIn { isLocked = false }
        }
        .onAppear {
            #if !DEBUG
            if JailbreakDetector.isJailbroken { isJailbroken = true }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToBooking)) { notif in
            if let bookingId = notif.userInfo?["bookingId"] as? String {
                deepLinkBookingId = bookingId
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDispute)) { notif in
            if let disputeId = notif.userInfo?["disputeId"] as? String {
                deepLinkDisputeId = disputeId
            }
        }
    }

    // MARK: - Privacy Shield

    private var privacyShield: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("PiumsLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 100)
                .opacity(0.2)
        }
        .ignoresSafeArea()
    }

    // MARK: - Lock Screen

    private var lockScreen: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Image("PiumsLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
                    .opacity(0.85)

                Text("Sesión bloqueada")
                    .font(.headline)
                    .foregroundStyle(.white)

                Button {
                    Task { await unlockWithBiometrics() }
                } label: {
                    Label("Desbloquear", systemImage: "faceid")
                        .font(.body.weight(.semibold))
                        .frame(width: 200, height: 50)
                        .background(Color(red: 0.85, green: 0.38, blue: 0.12))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Jailbreak Block Screen

    private var jailbreakBlockScreen: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Image("PiumsLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
                    .opacity(0.6)
                Text("Dispositivo no compatible")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Esta aplicación no puede ejecutarse en dispositivos con acceso root o jailbreak por razones de seguridad.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Biometric Auth

    private func unlockWithBiometrics() async {
        let context = LAContext()
        var nserror: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &nserror) else {
            await MainActor.run { isLocked = false }
            return
        }
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Verifica tu identidad para acceder a Piums"
            )
            if ok { await MainActor.run { isLocked = false } }
        } catch {
            // Cancelado o fallido — el usuario puede reintentar con el botón
        }
    }
}

#Preview {
    RootView()
}
