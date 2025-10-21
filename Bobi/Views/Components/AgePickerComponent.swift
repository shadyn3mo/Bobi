import SwiftUI

struct AgePickerComponent: View {
    @Binding var years: Int
    @Binding var months: Int
    @State private var pickerMode: PickerMode = .years
    
    enum PickerMode: String, CaseIterable {
        case years = "age.picker.mode.years"
        case months = "age.picker.mode.months"
        
        var localizedTitle: String {
            rawValue.localized
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 分段控制器
            Picker("", selection: $pickerMode) {
                ForEach(PickerMode.allCases, id: \.self) { mode in
                    Text(mode.localizedTitle).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: pickerMode) { _, newMode in
                switch newMode {
                case .months:
                    // 切换到月龄模式时，自动将年龄设置为0
                    years = 0
                    // 如果当前月龄为0，设置为1（最小值）
                    if months == 0 {
                        months = 1
                    }
                case .years:
                    // 切换到年龄模式时，清除月龄
                    months = 0
                    // 如果当前年龄为0，设置为1（避免显示0岁）
                    if years == 0 {
                        years = 1
                    }
                }
            }
            
            // 滚轮选择器
            Group {
                switch pickerMode {
                case .years:
                    Picker("age.picker.years.label".localized, selection: $years) {
                        ForEach(0...100, id: \.self) { year in
                            Text("\(year) " + (year == 1 ? "age.picker.year.singular".localized : "age.picker.year.plural".localized))
                                .tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    
                case .months:
                    Picker("age.picker.months.label".localized, selection: $months) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month) " + (month == 1 ? "age.picker.month.singular".localized : "age.picker.month.plural".localized))
                                .tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                }
            }
            .frame(height: 120)
            .clipped()
        }
        .onAppear {
            // 根据当前值设置初始模式
            if years == 0 && months > 0 {
                pickerMode = .months
            } else if years > 0 {
                pickerMode = .years
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var years = 25
        @State private var months = 6
        
        var body: some View {
            AgePickerComponent(
                years: $years,
                months: $months
            )
            .padding()
        }
    }
    
    return PreviewWrapper()
}