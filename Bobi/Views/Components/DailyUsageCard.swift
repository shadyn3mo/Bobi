import SwiftUI

struct DailyUsageCard: View {
    @StateObject private var usageManager = DailyUsageManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.title2)
                    
                    Text("ai.free.service.title".localized)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if usageManager.remainingUsage > 0 {
                    Text("\(usageManager.remainingUsage)")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                } else {
                    Text("0")
                        .font(.title2.bold())
                        .foregroundColor(.red)
                }
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("usage.remaining".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(usageManager.remainingUsage)/\(usageManager.totalDailyLimit)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: 1.0 - usageManager.usagePercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: usageManager.remainingUsage > 0 ? .green : .red))
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
            
            // Status Message
            HStack {
                Image(systemName: usageManager.remainingUsage > 0 ? "checkmark.circle.fill" : "clock.fill")
                    .foregroundColor(usageManager.remainingUsage > 0 ? .green : .orange)
                    .font(.caption)
                
                if usageManager.remainingUsage > 0 {
                    Text("usage.available".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("usage.reset.time".localized(with: usageManager.timeUntilReset))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

struct CompactDailyUsageView: View {
    @StateObject private var usageManager = DailyUsageManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(.purple)
                .font(.caption)
            
            Text("\(usageManager.remainingUsage)/\(usageManager.totalDailyLimit)")
                .font(.caption.monospacedDigit())
                .foregroundColor(usageManager.remainingUsage > 0 ? .green : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        DailyUsageCard()
        CompactDailyUsageView()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}