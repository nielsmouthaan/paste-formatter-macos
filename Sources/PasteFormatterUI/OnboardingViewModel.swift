import Combine
import Foundation

@MainActor
public final class OnboardingViewModel: ObservableObject {
    public enum Step: Int, CaseIterable {
        case accessibilityPermissions
        case launchAtLogin
        case keyboardShortcut
    }

    public enum AccessibilityPermissionState {
        case waiting
        case granted
    }

    public enum LaunchAtLoginState: Equatable {
        case notEnabled
        case enabled
        case requiresApproval
        case failed(String)
    }

    public enum LaunchAtLoginActionResult {
        case success(LaunchAtLoginState)
        case failure(String)
    }

    @Published var currentStep: Step
    @Published private(set) var accessibilityPermissionState: AccessibilityPermissionState
    @Published private(set) var launchAtLoginState: LaunchAtLoginState
    @Published private(set) var keyboardShortcut: KeyboardShortcut

    private let isAccessibilityTrusted: @MainActor () -> Bool
    private let openAccessibilitySettings: @MainActor () -> Void
    private let accessibilityPermissionGranted: @MainActor () -> Void
    private let launchAtLoginStateProvider: @MainActor () -> LaunchAtLoginState
    private let enableLaunchAtLogin: @MainActor () -> LaunchAtLoginActionResult
    private let openLaunchAtLoginSettings: @MainActor () -> Void
    private let recordKeyboardShortcut: @MainActor () -> KeyboardShortcut?
    private let completeOnboarding: @MainActor () -> Void
    private var permissionPollingTask: Task<Void, Never>?
    private var launchAtLoginPollingTask: Task<Void, Never>?

    public init(
        currentStep: Step = .accessibilityPermissions,
        accessibilityPermissionState: AccessibilityPermissionState = .waiting,
        launchAtLoginState: LaunchAtLoginState = .notEnabled,
        keyboardShortcut: KeyboardShortcut = .default,
        isAccessibilityTrusted: @escaping @MainActor () -> Bool,
        openAccessibilitySettings: @escaping @MainActor () -> Void,
        accessibilityPermissionGranted: @escaping @MainActor () -> Void,
        launchAtLoginStateProvider: @escaping @MainActor () -> LaunchAtLoginState,
        enableLaunchAtLogin: @escaping @MainActor () -> LaunchAtLoginActionResult,
        openLaunchAtLoginSettings: @escaping @MainActor () -> Void,
        recordKeyboardShortcut: @escaping @MainActor () -> KeyboardShortcut?,
        completeOnboarding: @escaping @MainActor () -> Void
    ) {
        self.currentStep = currentStep
        self.accessibilityPermissionState = accessibilityPermissionState
        self.launchAtLoginState = launchAtLoginState
        self.keyboardShortcut = keyboardShortcut
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.openAccessibilitySettings = openAccessibilitySettings
        self.accessibilityPermissionGranted = accessibilityPermissionGranted
        self.launchAtLoginStateProvider = launchAtLoginStateProvider
        self.enableLaunchAtLogin = enableLaunchAtLogin
        self.openLaunchAtLoginSettings = openLaunchAtLoginSettings
        self.recordKeyboardShortcut = recordKeyboardShortcut
        self.completeOnboarding = completeOnboarding

        refreshAccessibilityPermissionState()
        refreshLaunchAtLoginState()
    }

    deinit {
        permissionPollingTask?.cancel()
        launchAtLoginPollingTask?.cancel()
    }

    var isNextEnabled: Bool {
        currentStep != .accessibilityPermissions || accessibilityPermissionState == .granted
    }

    var isNextPrimary: Bool {
        isNextEnabled
    }

    var nextButtonTitle: String {
        currentStep == .keyboardShortcut ? "Finish" : "Next"
    }

    var accessibilitySettingsButtonIsEnabled: Bool {
        accessibilityPermissionState != .granted
    }

    var launchAtLoginButtonTitle: String {
        switch launchAtLoginState {
        case .requiresApproval:
            "Open System Settings"
        default:
            "Launch at Login"
        }
    }

    var launchAtLoginButtonIsEnabled: Bool {
        switch launchAtLoginState {
        case .enabled:
            false
        default:
            true
        }
    }

    func startMonitoringAccessibilityPermission() {
        permissionPollingTask?.cancel()
        permissionPollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refreshAccessibilityPermissionState(notifyWhenGranted: true)
                if self?.accessibilityPermissionState == .granted {
                    break
                }

                try? await Task.sleep(for: .milliseconds(700))
            }
        }
    }

    func openAccessibilitySettingsButtonPressed() {
        openAccessibilitySettings()
        startMonitoringAccessibilityPermission()
    }

    func launchAtLoginButtonPressed() {
        if launchAtLoginState == .requiresApproval {
            openLaunchAtLoginSettings()
            startMonitoringLaunchAtLoginApproval()
            return
        }

        switch enableLaunchAtLogin() {
        case .success(let state):
            launchAtLoginState = state
            if launchAtLoginState == .requiresApproval {
                startMonitoringLaunchAtLoginApproval()
            }
        case .failure(let message):
            launchAtLoginState = .failed(message)
        }
    }

    func changeKeyboardShortcut() {
        guard let shortcut = recordKeyboardShortcut() else {
            return
        }

        keyboardShortcut = shortcut
    }

    func advance() {
        guard isNextEnabled else {
            return
        }

        switch currentStep {
        case .accessibilityPermissions:
            currentStep = .launchAtLogin
        case .launchAtLogin:
            currentStep = .keyboardShortcut
        case .keyboardShortcut:
            completeOnboarding()
        }
    }

    func refreshAccessibilityPermissionState() {
        refreshAccessibilityPermissionState(notifyWhenGranted: false)
    }

    private func refreshAccessibilityPermissionState(notifyWhenGranted: Bool) {
        let previousState = accessibilityPermissionState
        accessibilityPermissionState = isAccessibilityTrusted() ? .granted : .waiting

        if notifyWhenGranted,
           previousState == .waiting,
           accessibilityPermissionState == .granted {
            accessibilityPermissionGranted()
        }
    }

    func refreshLaunchAtLoginState() {
        launchAtLoginState = launchAtLoginStateProvider()
    }

    private func startMonitoringLaunchAtLoginApproval() {
        launchAtLoginPollingTask?.cancel()
        launchAtLoginPollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refreshLaunchAtLoginState()

                if self?.launchAtLoginState != .requiresApproval {
                    break
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
