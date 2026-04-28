import AppKit
import PasteFormatterUI
import ServiceManagement
import SwiftUI

typealias PFKeyboardShortcut = PasteFormatterUI.KeyboardShortcut

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let settingsStore: SettingsStore
    private let launchAtLoginService: LaunchAtLoginService
    private let currentKeyboardShortcut: @MainActor () -> PFKeyboardShortcut
    private let recordKeyboardShortcut: @MainActor () -> PFKeyboardShortcut?

    private var hostingView: NSHostingView<OnboardingView>?
    private var viewModel: OnboardingViewModel?
    private var isCompletingOnboarding = false

    init(
        settingsStore: SettingsStore,
        launchAtLoginService: LaunchAtLoginService,
        currentKeyboardShortcut: @escaping @MainActor () -> PFKeyboardShortcut,
        recordKeyboardShortcut: @escaping @MainActor () -> PFKeyboardShortcut?
    ) {
        self.settingsStore = settingsStore
        self.launchAtLoginService = launchAtLoginService
        self.currentKeyboardShortcut = currentKeyboardShortcut
        self.recordKeyboardShortcut = recordKeyboardShortcut

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSZeroSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        configureWindow(window)
        configureContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showIfNeeded() {
        guard !settingsStore.didCompleteOnboarding else {
            return
        }

        showCentered()
    }

    private func configureWindow(_ window: NSWindow) {
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
    }

    private func configureContent() {
        let viewModel = OnboardingViewModel(
            keyboardShortcut: currentKeyboardShortcut(),
            isAccessibilityTrusted: {
                AccessibilityPermissionController.isTrusted
            },
            openAccessibilitySettings: {
                AccessibilityPermissionController.openSettings()
            },
            accessibilityPermissionGranted: { [weak self] in
                self?.bringToFront()
            },
            launchAtLoginStateProvider: { [launchAtLoginService] in
                Self.onboardingLaunchAtLoginState(for: launchAtLoginService.status)
            },
            enableLaunchAtLogin: { [launchAtLoginService] in
                switch launchAtLoginService.setEnabled(true) {
                case .success:
                    .success(Self.onboardingLaunchAtLoginState(for: launchAtLoginService.status))
                case .failure(let error):
                    .failure(error.localizedDescription)
                }
            },
            openLaunchAtLoginSettings: { [launchAtLoginService] in
                launchAtLoginService.openSystemSettings()
            },
            recordKeyboardShortcut: { [recordKeyboardShortcut] in
                recordKeyboardShortcut()
            },
            completeOnboarding: { [weak self] in
                self?.completeOnboarding()
            }
        )
        let hostingView = NSHostingView(rootView: OnboardingView(viewModel: viewModel))

        self.viewModel = viewModel
        self.hostingView = hostingView
        window?.contentView = hostingView
        updateWindowSize()
    }

    private func showCentered() {
        guard let window else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        updateWindowSize()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func bringToFront() {
        guard let window else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    private func completeOnboarding() {
        isCompletingOnboarding = true
        settingsStore.didCompleteOnboarding = true
        window?.close()
        isCompletingOnboarding = false
    }

    private static func onboardingLaunchAtLoginState(
        for status: SMAppService.Status
    ) -> OnboardingViewModel.LaunchAtLoginState {
        switch status {
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notRegistered, .notFound:
            .notEnabled
        @unknown default:
            .notEnabled
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard !isCompletingOnboarding else {
            return
        }

        NSApp.terminate(nil)
    }

    private func updateWindowSize() {
        guard
            let window,
            let hostingView
        else {
            return
        }

        hostingView.layoutSubtreeIfNeeded()
        let contentSize = hostingView.fittingSize
        window.setContentSize(contentSize)
        window.contentMinSize = contentSize
        window.contentMaxSize = contentSize
    }
}
