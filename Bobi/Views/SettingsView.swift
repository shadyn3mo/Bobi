//
//  SettingsView.swift
//  GogoFridge
//
//  Created by Jeremy Zhang on 6/11/25.
//  Refactored by Claude Code on 6/18/25.
//

import SwiftUI
import SwiftData

// MARK: - Main Settings View
struct SettingsView: View {
    @State private var localizationManager = LocalizationManager.shared
    @State private var handednessManager = HandednessManager.shared
    @State private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    private var languages: [(String, String)] {
        [
            ("en", "language.english".localized),
            ("zh-Hans", "language.chinese.simplified".localized)
        ]
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header Section
                            VStack(spacing: 20) {
                                HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                Image("repairing_view")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 95, height: 95)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("settings.title".localized)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                Text("settings.subtitle".localized)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                                }
                                
                                FamilyBannerView()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            .padding(.top, 10)
                            .background(
                                GeometryReader { headerGeometry in
                                    LinearGradient(
                                        colors: premiumBackgroundColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .overlay(
                                        Circle()
                                            .fill(
                                                RadialGradient(
                                                    colors: [.purple.opacity(0.15), .clear],
                                                    center: .topLeading,
                                                    startRadius: 0,
                                                    endRadius: 200
                                                )
                                            )
                                            .frame(width: 400, height: 400)
                                            .offset(x: -100, y: -100)
                                            .blur(radius: 20)
                                    )
                                    .frame(height: headerGeometry.size.height + geometry.safeAreaInsets.top)
                                    .offset(y: -geometry.safeAreaInsets.top)
                                }
                            )
                    
                    // Settings Options
                    VStack(spacing: 20) {
                        
                        // App & Interface Settings
                        SettingsGroupView(title: "settings.group.interface".localized) {
                            VStack(spacing: 6) {
                                NavigationLink(destination: AppIconSelectionView()) {
                                    ModernSettingsRowView(
                                        icon: "app.dashed",
                                        iconColor: .blue,
                                        title: "change.app.icon".localized
                                    )
                                }
                                
                                // Language Selection
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.green)
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "globe.americas.fill")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("interface.language".localized)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $localizationManager.selectedLanguage) {
                                        ForEach(languages, id: \.0) { language in
                                            Text(language.1).tag(language.0)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .labelsHidden()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                )
                                
                                // Theme Selection
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.purple)
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "paintpalette.fill")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("interface.theme".localized)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $themeManager.selectedTheme) {
                                        ForEach(AppTheme.allCases, id: \.self) { theme in
                                            Text(theme.localizedName)
                                                .tag(theme)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .labelsHidden()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                )
                                
                                // Handedness Selection
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.orange)
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "hand.point.up.left.fill")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("interface.handedness".localized)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $handednessManager.selectedHandedness) {
                                        ForEach(Handedness.allCases, id: \.self) { handedness in
                                            Text(handedness.localizedName)
                                                .tag(handedness)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .labelsHidden()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                )
                            }
                        }
                        
                        // AI Settings
                        SettingsGroupView(title: "settings.group.ai".localized) {
                            VStack(spacing: 6) {
                                NavigationLink(destination: AIConnectionView()) {
                                    ModernSettingsRowView(
                                        icon: "brain.head.profile",
                                        iconColor: .purple,
                                        title: "ai.chef.settings".localized
                                    )
                                }
                            }
                        }
                        
                        // Privacy & Notifications Settings
                        SettingsGroupView(title: "settings.group.privacy".localized) {
                            VStack(spacing: 6) {
                                NavigationLink(destination: NotificationSettingsView()) {
                                    ModernSettingsRowView(
                                        icon: "bell.circle.fill",
                                        iconColor: .red,
                                        title: "settings.notifications".localized
                                    )
                                }
                                
                                NavigationLink(destination: PrivacySecurityView()) {
                                    ModernSettingsRowView(
                                        icon: "hand.raised.circle.fill",
                                        iconColor: .indigo,
                                        title: "settings.privacy".localized
                                    )
                                }
                            }
                        }
                        
                        // Feedback & Support Settings
                        SettingsGroupView(title: "settings.group.support".localized) {
                            VStack(spacing: 6) {
                                NavigationLink(destination: FeedbackView()) {
                                    ModernSettingsRowView(
                                        icon: "bubble.left.and.bubble.right.fill",
                                        iconColor: .blue,
                                        title: "feedback.beta.title".localized
                                    )
                                }
                                
                                Button(action: openAppStore) {
                                    ModernSettingsRowView(
                                        icon: "star.fill",
                                        iconColor: .yellow,
                                        title: "feedback.rate.app".localized
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: shareBobi) {
                                    ModernSettingsRowView(
                                        icon: "square.and.arrow.up",
                                        iconColor: .green,
                                        title: "share.bobi.button".localized
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                NavigationLink(destination: JoinTranslationView()) {
                                    ModernSettingsRowView(
                                        icon: "globe.asia.australia.fill",
                                        iconColor: .orange,
                                        title: "settings.join.translation".localized
                                    )
                                }
                                
                                NavigationLink(destination: AboutView()) {
                                    ModernSettingsRowView(
                                        icon: "person.crop.circle.fill",
                                        iconColor: .purple,
                                        title: "about.navigation.title".localized
                                    )
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                        }
                    }
                }
            }
        }
    }
    
    private var premiumBackgroundColors: [Color] {
        switch themeManager.selectedTheme {
        case .dark:
            return [
                Color.black.opacity(0.98),
                Color(.systemGray5).opacity(0.8),
                Color.black.opacity(0.95)
            ]
        case .light:
            return [
                Color(.systemBackground),
                Color.purple.opacity(0.05),
                Color(.secondarySystemBackground)
            ]
        case .auto:
            return colorScheme == .dark
                ? [
                    Color.black.opacity(0.98),
                    Color(.systemGray5).opacity(0.8),
                    Color.black.opacity(0.95)
                ]
                : [
                    Color(.systemBackground),
                    Color.purple.opacity(0.05),
                    Color(.secondarySystemBackground)
                ]
        }
    }
    
    private func openAppStore() {
        if let url = URL(string: "https://apps.apple.com/app/apple-store/id375380948") {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareBobi() {
        let shareText = "share.bobi.content".localized
        let shareURL = URL(string: "https://www.getbobi.app")!
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText, shareURL],
            applicationActivities: nil
        )
        
        // Find the key window and root view controller to present the share sheet
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first { $0.isKeyWindow }

        if let rootViewController = keyWindow?.rootViewController {
            // For iPad, configure the popover to appear from the center.
            // On iPhone, this configuration is ignored and it presents as a standard sheet.
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(
                    x: rootViewController.view.bounds.midX,
                    y: rootViewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                // Hiding the arrow makes it present as a centered popover on iPad.
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - Settings Group View
struct SettingsGroupView<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.colorScheme) var colorScheme
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                content
            }
        }
    }
    
    private var groupBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.secondarySystemBackground)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05)
    }
}

// MARK: - Modern Settings Row
struct ModernSettingsRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .contentShape(Rectangle())
    }
}

