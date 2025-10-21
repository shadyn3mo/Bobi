import SwiftUI
import UIKit

// MARK: - Feedback View
struct FeedbackView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Spacer().frame(height: 40)
                
                // Header Section
                VStack(spacing: 20) {
                    Text("feedback.description".localized)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 30)
                }
                
                // Quick Feedback Section
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "clipboard")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("feedback.quick.title".localized)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Text("feedback.quick.description".localized)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                    
                    Button(action: sendFeedback) {
                        Text("feedback.give.feedback".localized)
                            .font(.headline)
                            .foregroundColor(buttonTextColor)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(buttonBackgroundColor)
                            .cornerRadius(25)
                            .glassedEffect(in: RoundedRectangle(cornerRadius: 25), interactive: true)
                    }
                    .padding(.horizontal, 30)
                }
                
                // Join Research Section
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("research.join.title".localized)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Text("research.join.description".localized)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                    
                    // Benefits list
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("research.benefits.early.access".localized)
                                .font(.body)
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("research.benefits.suggestions".localized)
                                .font(.body)
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("research.benefits.no.pressure".localized)
                                .font(.body)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Button(action: joinBeta) {
                        Text("research.join.beta".localized)
                            .font(.headline)
                            .foregroundColor(buttonTextColor)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(buttonBackgroundColor)
                            .cornerRadius(25)
                            .glassedEffect(in: RoundedRectangle(cornerRadius: 25), interactive: true)
                    }
                    .padding(.horizontal, 30)
                }
                
                // Just Say Hi Section
                VStack(spacing: 20) {
                    HStack {
                        Text("👋")
                            .font(.title2)
                        
                        Text("contact.say.hi.title".localized)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Text("contact.description".localized)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                    
                    Button(action: contactUs) {
                        Text("contact.write.email".localized)
                            .font(.headline)
                            .foregroundColor(buttonTextColor)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(buttonBackgroundColor)
                            .cornerRadius(25)
                            .glassedEffect(in: RoundedRectangle(cornerRadius: 25), interactive: true)
                    }
                    .padding(.horizontal, 30)
                }
                
                Spacer()
            }
        }
        .navigationTitle("feedback.beta.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(false)
    }
    
    private var buttonBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.9) : Color.black
    }
    
    private var buttonTextColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private func sendFeedback() {
        if let url = URL(string: "https://forms.google.com/") {
            UIApplication.shared.open(url)
        }
    }
    
    private func joinBeta() {
        if let url = URL(string: "mailto:support@getbobi.app?subject=Join Bobi Fridge Beta") {
            UIApplication.shared.open(url)
        }
    }
    
    
    
    private func contactUs() {
        if let url = URL(string: "mailto:support@getbobi.app?subject=Bobi Fridge Support") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Spacer().frame(height: 40)
                
                // App Icon and Title
                VStack(spacing: 20) {
                    Image("about_view")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                    
                    Text("Bobi Fridge")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("about.description.intro".localized)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                }
                
                // Features
                VStack(spacing: 20) {
                    Text("about.description.features".localized)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                }
                
                
                // Footer
                VStack(spacing: 12) {
                    Text("about.description.footer".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 50) // 缩小行宽
                    
                    Text("Version 0.1.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // 隐私协议和用户协议链接
                    HStack(spacing: 20) {
                        Button(action: openPrivacyPolicy) {
                            Text("about.privacy.policy".localized)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .underline()
                        }
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: openTermsOfUse) {
                            Text("about.terms.of.use".localized)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .underline()
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 40)
                
                Spacer()
            }
        }
        .navigationTitle("about.navigation.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(false)
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://www.getbobi.app/privacy-policy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfUse() {
        if let url = URL(string: "https://www.getbobi.app/terms-of-use") {
            UIApplication.shared.open(url)
        }
    }
    
}

// MARK: - Join Translation View
struct JoinTranslationView: View {
    @Environment(\.colorScheme) var colorScheme
    
    // 翻译者数据结构
    struct Translator {
        let name: String
        let language: String
        let languageCode: String
        let contributionLevel: String // "lead", "contributor", "reviewer"
    }
    
    // 示例翻译者数据，未来可以从服务器获取
    let translators: [Translator] = [
        // 这里将来会添加实际的翻译者名单
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Spacer().frame(height: 40)
                
                // Header Section with warm welcome
                VStack(spacing: 20) {
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                        .padding(.bottom, 10)
                    
                    Text("translation.join.title".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("translation.join.subtitle".localized)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                }
                
                // Why Join Section
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundColor(.pink)
                        
                        Text("translation.why.join.title".localized)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "person.3.fill", 
                                  text: "translation.benefit.community".localized,
                                  color: .blue)
                        
                        FeatureRow(icon: "sparkles", 
                                  text: "translation.benefit.early.access".localized,
                                  color: .orange)
                        
                        FeatureRow(icon: "medal.fill", 
                                  text: "translation.benefit.recognition".localized,
                                  color: .yellow)
                        
                        FeatureRow(icon: "gift.fill", 
                                  text: "translation.benefit.rewards".localized,
                                  color: .purple)
                    }
                    .padding(.horizontal, 40)
                }
                
                // Current Contributors Section (将来展示)
                if !translators.isEmpty {
                    VStack(spacing: 20) {
                        HStack {
                            Image(systemName: "hands.sparkles.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                            
                            Text("translation.contributors.title".localized)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        // 翻译者卡片网格
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            ForEach(translators, id: \.name) { translator in
                                TranslatorCard(translator: translator)
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                }
                
                // Join Button Section
                VStack(spacing: 20) {
                    Text("translation.ready.to.help".localized)
                        .font(.title3)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Button(action: openTranslationForm) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                                .font(.headline)
                            Text("translation.join.button".localized)
                                .font(.headline)
                        }
                        .foregroundColor(buttonTextColor)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(buttonBackgroundColor)
                        .cornerRadius(25)
                        .glassedEffect(in: RoundedRectangle(cornerRadius: 25), interactive: true)
                    }
                    .padding(.horizontal, 30)
                    
                    Text("translation.form.description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
            }
        }
        .navigationTitle("translation.navigation.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
    
    private var buttonBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.9) : Color.black
    }
    
    private var buttonTextColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private func openTranslationForm() {
        // 这里替换为实际的 Google Sheet 表单链接
        if let url = URL(string: "https://forms.gle/YOUR_FORM_ID") {
            UIApplication.shared.open(url)
        }
    }
}

// Feature Row Component
private struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// Translator Card Component
private struct TranslatorCard: View {
    let translator: JoinTranslationView.Translator
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            // Language flag emoji based on language code
            Text(flagEmoji(for: translator.languageCode))
                .font(.system(size: 36))
            
            Text(translator.name)
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(translator.language)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Contribution level badge
            Text(contributionBadge)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.2))
                .foregroundColor(badgeColor)
                .cornerRadius(10)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var contributionBadge: String {
        switch translator.contributionLevel {
        case "lead": return "Lead"
        case "reviewer": return "Reviewer"
        default: return "Contributor"
        }
    }
    
    private var badgeColor: Color {
        switch translator.contributionLevel {
        case "lead": return .orange
        case "reviewer": return .blue
        default: return .green
        }
    }
    
    private func flagEmoji(for languageCode: String) -> String {
        switch languageCode {
        case "zh-Hans": return "🇨🇳"
        case "zh-Hant": return "🇹🇼"
        case "en": return "🇺🇸"
        case "ja": return "🇯🇵"
        case "ko": return "🇰🇷"
        case "es": return "🇪🇸"
        case "fr": return "🇫🇷"
        case "de": return "🇩🇪"
        case "it": return "🇮🇹"
        case "pt": return "🇵🇹"
        case "ru": return "🇷🇺"
        case "ar": return "🇸🇦"
        case "hi": return "🇮🇳"
        default: return "🌍"
        }
    }
}
