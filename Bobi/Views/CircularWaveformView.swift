import SwiftUI
import simd

struct CircularWaveformView: View {
    var audioLevel: Float
    @Binding var isRecording: Bool
    
    private let barCount = 120
    private let innerParticleCount = 35
    private let outerParticleCount = 25
    private var innerBarCount: Int { Int(Double(barCount) * 0.6) }
    private var secondaryParticleCount: Int { Int(Double(innerParticleCount) * 0.7) }
    
    // Enhanced gradients for modern look
    private let primaryGradient = AngularGradient(
        gradient: Gradient(colors: [
            Color.cyan.opacity(0.9),
            Color.blue.opacity(1.0),
            Color.purple.opacity(0.9),
            Color.pink.opacity(0.8),
            Color.orange.opacity(0.7),
            Color.cyan.opacity(0.9)
        ]),
        center: .center,
        startAngle: .degrees(0),
        endAngle: .degrees(360)
    )
    
    private let secondaryGradient = AngularGradient(
        gradient: Gradient(colors: [
            Color.indigo.opacity(0.7),
            Color.purple.opacity(0.8),
            Color.pink.opacity(0.7),
            Color.red.opacity(0.6),
            Color.indigo.opacity(0.7)
        ]),
        center: .center,
        startAngle: .degrees(45),
        endAngle: .degrees(405)
    )
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSince1970
            
            ZStack {
                if isRecording {
                    backgroundPulseRing
                }
                
                outerWaveformRing(time: time)
                innerWaveformRing(time: time)
                
                if isRecording {
                    particleEffects(time: time)
                    centralPulseEffect
                }
            }
            .animation(.easeInOut(duration: 0.12), value: audioLevel)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isRecording)
        }
    }
    
    private var backgroundPulseRing: some View {
        let pulseGradient = LinearGradient(
            colors: [
                Color.white.opacity(0.2),
                Color.cyan.opacity(0.3),
                Color.blue.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        return Circle()
            .stroke(pulseGradient, lineWidth: 2)
            .frame(width: 140, height: 140)
            .scaleEffect(1.0 + CGFloat(audioLevel) * 0.3)
            .opacity(0.6 - CGFloat(audioLevel) * 0.2)
            .animation(.easeInOut(duration: 0.2), value: audioLevel)
    }
    
    private func outerWaveformRing(time: Double) -> some View {
        ForEach(0..<barCount, id: \.self) { index in
            let barHeight = self.outerBarHeight(for: index, time: time)
            let rotationAngle = Double(index) * 360.0 / Double(barCount)
            
            Rectangle()
                .fill(primaryGradient)
                .frame(width: 2.5, height: barHeight)
                .offset(y: -65)
                .rotationEffect(.degrees(rotationAngle))
                .opacity(isRecording ? 1.0 : 0.4)
                .blur(radius: isRecording ? 0.3 : 0.8)
        }
    }
    
    private func innerWaveformRing(time: Double) -> some View {
        ForEach(0..<innerBarCount, id: \.self) { index in
            let barHeight = self.innerBarHeight(for: index, time: time)
            let rotationAngle = Double(index) * 360.0 / Double(innerBarCount) + time * 20
            
            Rectangle()
                .fill(secondaryGradient)
                .frame(width: 2, height: barHeight)
                .offset(y: -45)
                .rotationEffect(.degrees(rotationAngle))
                .opacity(isRecording ? 0.8 : 0.3)
                .blur(radius: 0.5)
        }
    }
    
    private func particleEffects(time: Double) -> some View {
        ZStack {
            primaryParticleSpiral(time: time)
            secondaryParticleSpiral(time: time)
            outerFloatingParticles(time: time)
        }
    }
    
    private func primaryParticleSpiral(time: Double) -> some View {
        ForEach(0..<innerParticleCount, id: \.self) { index in
            let angle = Angle(degrees: (Double(index) / Double(innerParticleCount)) * 360 - time * 90)
            let radius = 28 + sin(time * 2.5 + Double(index) * 0.4) * 6
            let offsetX = cos(angle.radians) * radius
            let offsetY = sin(angle.radians) * radius
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, Color.cyan.opacity(0.8)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 2
                    )
                )
                .frame(width: 3, height: 3)
                .offset(x: offsetX, y: offsetY)
                .blur(radius: 0.5)
        }
    }
    
    private func secondaryParticleSpiral(time: Double) -> some View {
        ForEach(0..<secondaryParticleCount, id: \.self) { index in
            let angle = Angle(degrees: (Double(index) / Double(secondaryParticleCount)) * 360 + time * 60)
            let radius = 22 + cos(time * 1.8 + Double(index) * 0.3) * 4
            let offsetX = cos(angle.radians) * radius
            let offsetY = sin(angle.radians) * radius
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.pink.opacity(0.9), Color.purple.opacity(0.6)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 1.5
                    )
                )
                .frame(width: 2.5, height: 2.5)
                .offset(x: offsetX, y: offsetY)
                .blur(radius: 0.3)
        }
    }
    
    private func outerFloatingParticles(time: Double) -> some View {
        ForEach(0..<outerParticleCount, id: \.self) { index in
            let angle = Angle(degrees: (Double(index) / Double(outerParticleCount)) * 360 + time * 25)
            let radius = 50 + sin(time * 1.2 + Double(index) * 0.5) * 8
            let offsetX = cos(angle.radians) * radius
            let offsetY = sin(angle.radians) * radius
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.7), Color.red.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 2, height: 2)
                .offset(x: offsetX, y: offsetY)
                .blur(radius: 0.8)
                .opacity(0.7)
        }
    }
    
    private var centralPulseEffect: some View {
        ZStack {
            let audioLevelCG = CGFloat(audioLevel)
            
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: 15 + audioLevelCG * 25, height: 15 + audioLevelCG * 25)
                .scaleEffect(1.0 + audioLevelCG * 0.4)
                .opacity(0.8 - audioLevelCG * 0.4)
            
            Circle()
                .stroke(Color.cyan.opacity(0.2), lineWidth: 0.5)
                .frame(width: 25 + audioLevelCG * 35, height: 25 + audioLevelCG * 35)
                .scaleEffect(1.0 + audioLevelCG * 0.2)
                .opacity(0.6 - audioLevelCG * 0.3)
        }
    }
    
    private func outerBarHeight(for index: Int, time: Double) -> CGFloat {
        let idleHeight: CGFloat = 6
        guard isRecording else { return idleHeight }
        
        let indexRatio = Double(index) / Double(barCount)
        let phaseShift = time * 4.5
        
        let wave1 = sin(indexRatio * .pi * 5 + phaseShift)
        let wave2 = sin(indexRatio * .pi * 11 + phaseShift * 1.3)
        let wave3 = cos(indexRatio * .pi * 7 + phaseShift * 0.7)
        
        let weightedWave1 = wave1
        let weightedWave2 = wave2 * 0.8
        let weightedWave3 = wave3 * 0.6
        let combinedWave = (weightedWave1 + weightedWave2 + weightedWave3) / 2.4
        
        let audioLevelCG = CGFloat(audioLevel)
        let dynamicHeight = audioLevelCG * 45 * abs(CGFloat(combinedWave))
        
        return idleHeight + dynamicHeight
    }
    
    private func innerBarHeight(for index: Int, time: Double) -> CGFloat {
        let idleHeight: CGFloat = 4
        guard isRecording else { return idleHeight }
        
        let indexRatio = Double(index) / Double(innerBarCount)
        let phaseShift = time * 6
        
        let wave1 = cos(indexRatio * .pi * 9 + phaseShift)
        let wave2 = sin(indexRatio * .pi * 13 + phaseShift * 1.5)
        
        let combinedWave = (wave1 + wave2 * 0.7) / 1.7
        let audioLevelCG = CGFloat(audioLevel)
        let dynamicHeight = audioLevelCG * 30 * abs(CGFloat(combinedWave))
        
        return idleHeight + dynamicHeight
    }
} 