import SwiftUI
import SwiftData

struct DataRecoveryView: View {
    let error: Error
    @State private var showingResetConfirmation = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 错误图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            // 标题和描述
            VStack(spacing: 16) {
                Text("data.recovery.title".localized)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("data.recovery.description".localized)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
            }
            
            // 解决方案
            VStack(spacing: 20) {
                Button(action: {
                    showingResetConfirmation = true
                }) {
                    Text("data.recovery.reset".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                
                Button(action: {
                    // 重启应用
                    exit(0)
                }) {
                    Text("data.recovery.restart".localized)
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // 错误详情
            VStack(spacing: 8) {
                Text("data.recovery.error.details".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .alert("data.recovery.confirm.title".localized, isPresented: $showingResetConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("data.recovery.reset.button".localized, role: .destructive) {
                resetAppData()
            }
        } message: {
            Text("data.recovery.confirm.message".localized)
        }
    }
    
    private func resetAppData() {
        // 删除应用的数据文件
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if let documentsURL = urls.first {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                for fileURL in fileURLs {
                    try FileManager.default.removeItem(at: fileURL)
                }
                print("Successfully reset app data")
                
                // 重启应用
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    exit(0)
                }
            } catch {
                print("Failed to reset app data: \(error)")
            }
        }
    }
}

#Preview {
    DataRecoveryView(error: NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error message"]))
}