import AppKit
import SwiftUI

public struct OnboardingView: View {
    @ObservedObject private var viewModel: OnboardingViewModel

    private let helpURL = URL(string: "https://paste-formatter.app/help")!

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                Group {
                    switch viewModel.currentStep {
                    case .accessibilityPermissions:
                        grantAccessibilityPermissionsStep
                    case .launchAtLogin:
                        launchAtLoginStep
                    case .keyboardShortcut:
                        keyboardShortcutStep
                    }
                }
                .id(viewModel.currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut, value: viewModel.currentStep)

            Spacer()
            footer
        }
        .frame(width: 380, height: 480)
        .padding(.top, 48)
        .padding(.bottom, 24)
        .padding(.horizontal, 24)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            viewModel.startMonitoringAccessibilityPermission()
        }
    }

    private var header: some View {
        VStack(spacing: 22) {
            appIcon

            VStack(spacing: 14) {
                Text("Paste Formatter")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Paste Formatter is a macOS menu bar app that formats and pastes rich text into the active app.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Follow this short setup to get the app ready.")
                    .font(.body)
                    .multilineTextAlignment(.center)
            }

            Divider()
                .padding(.horizontal, 40)
                .padding(.top, 4)
        }
        .padding(.bottom, 26)
    }

    private var appIcon: some View {
        let icon = Bundle.main.url(forResource: "OnboardingAppIcon", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
            ?? Bundle.module.url(forResource: "OnboardingAppIcon", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(size: NSSize(width: 64, height: 64))

        return Image(nsImage: icon)
            .resizable()
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)
    }

    private var grantAccessibilityPermissionsStep: some View {
        VStack(spacing: 24) {
            Text("Grant Accessibility Permissions")
                .font(.title2)

            Text("Accessibility permissions are required to paste formatted clipboard content into the active app.")
                .multilineTextAlignment(.center)

            accessibilitySettingsButton

            switch viewModel.accessibilityPermissionState {
            case .waiting:
                statusRow(kind: .progress, text: "Waiting for approval")
            case .granted:
                statusRow(kind: .success, text: "Permission granted")
            }
        }
    }

    @ViewBuilder
    private var accessibilitySettingsButton: some View {
        if viewModel.accessibilitySettingsButtonIsEnabled {
            Button("Open Accessibility Settings") {
                viewModel.openAccessibilitySettingsButtonPressed()
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button("Open Accessibility Settings") {}
                .buttonStyle(.bordered)
                .disabled(true)
        }
    }

    private var launchAtLoginStep: some View {
        VStack(spacing: 24) {
            Text("Launch at Login")
                .font(.title3)

            Text("Automatically launch at login to keep the app available whenever you need it.")
                .multilineTextAlignment(.center)

            launchAtLoginButton

            switch viewModel.launchAtLoginState {
            case .enabled:
                statusRow(kind: .success, text: "Launch at login enabled")
            case .requiresApproval:
                statusRow(kind: .warning, text: "Approval required in System Settings")
            case .failed(let message):
                statusRow(kind: .warning, text: message)
            case .notEnabled:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var launchAtLoginButton: some View {
        if viewModel.launchAtLoginState == .requiresApproval {
            Button(viewModel.launchAtLoginButtonTitle) {
                viewModel.launchAtLoginButtonPressed()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.launchAtLoginButtonIsEnabled)
        } else {
            Button(viewModel.launchAtLoginButtonTitle) {
                viewModel.launchAtLoginButtonPressed()
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.launchAtLoginButtonIsEnabled)
        }
    }

    private var keyboardShortcutStep: some View {
        VStack(spacing: 24) {
            Text("Keyboard Shortcut")
                .font(.title2)

            (
                Text("Paste via the app's menu or using the global keyboard shortcut ")
                    + Text(viewModel.keyboardShortcut.displayString).bold()
                    + Text(".")
            )
                .multilineTextAlignment(.center)

            Button("Change Keyboard Shortcut") {
                viewModel.changeKeyboardShortcut()
            }
            .buttonStyle(.bordered)
        }
    }

    private var footer: some View {
        ZStack {
            HStack {
                Spacer()

                HelpButton {
                    NSWorkspace.shared.open(helpURL)
                }
                .accessibilityLabel("Open help")
            }

            nextButton
        }
    }

    @ViewBuilder
    private var nextButton: some View {
        if viewModel.isNextPrimary {
            Button(viewModel.nextButtonTitle) {
                viewModel.advance()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isNextEnabled)
        } else {
            Button(viewModel.nextButtonTitle) {
                viewModel.advance()
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.isNextEnabled)
        }
    }

    private enum StatusKind {
        case progress
        case success
        case warning
    }

    private func statusRow(kind: StatusKind, text: String) -> some View {
        HStack {
            switch kind {
            case .progress:
                ProgressView()
                    .controlSize(.small)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }

            Text(text)
                .font(.body)
        }
    }
}

private struct HelpButton: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "", target: context.coordinator, action: #selector(Coordinator.performAction))
        button.setButtonType(NSButton.ButtonType.momentaryPushIn)
        button.bezelStyle = NSButton.BezelStyle.helpButton
        button.isBordered = true
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        private let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}

#Preview("Accessibility Permissions") {
    OnboardingView(viewModel: .preview(
        currentStep: .accessibilityPermissions,
        accessibilityPermissionState: .waiting
    ))
}

#Preview("Launch at Login") {
    OnboardingView(viewModel: .preview(
        currentStep: .launchAtLogin,
        accessibilityPermissionState: .granted,
        launchAtLoginState: .notEnabled
    ))
}

#Preview("Keyboard Shortcut") {
    OnboardingView(viewModel: .preview(
        currentStep: .keyboardShortcut,
        accessibilityPermissionState: .granted
    ))
}

extension OnboardingViewModel {
    static func preview(
        currentStep: Step,
        accessibilityPermissionState: AccessibilityPermissionState = .waiting,
        launchAtLoginState: LaunchAtLoginState = .notEnabled,
        keyboardShortcut: KeyboardShortcut = .default
    ) -> OnboardingViewModel {
        OnboardingViewModel(
            currentStep: currentStep,
            accessibilityPermissionState: accessibilityPermissionState,
            launchAtLoginState: launchAtLoginState,
            keyboardShortcut: keyboardShortcut,
            isAccessibilityTrusted: { accessibilityPermissionState == .granted },
            openAccessibilitySettings: {},
            accessibilityPermissionGranted: {},
            launchAtLoginStateProvider: {
                switch launchAtLoginState {
                case .enabled:
                    OnboardingViewModel.LaunchAtLoginState.enabled
                case .requiresApproval:
                    OnboardingViewModel.LaunchAtLoginState.requiresApproval
                case .notEnabled, .failed:
                    OnboardingViewModel.LaunchAtLoginState.notEnabled
                }
            },
            enableLaunchAtLogin: {
                OnboardingViewModel.LaunchAtLoginActionResult.success(.enabled)
            },
            openLaunchAtLoginSettings: {},
            recordKeyboardShortcut: { keyboardShortcut },
            completeOnboarding: {}
        )
    }
}
