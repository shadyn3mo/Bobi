import AVFoundation
import UIKit
import Combine

@MainActor
class CameraService: ObservableObject {
    @Published private var authorizationStatus: AVAuthorizationStatus
    
    init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }
    
    var authorizationStatusString: String {
        switch authorizationStatus {
        case .notDetermined:
            return "camera.permission.not.determined".localized
        case .restricted:
            return "camera.permission.restricted".localized
        case .denied:
            return "camera.permission.denied".localized
        case .authorized:
            return "camera.permission.authorized".localized
        @unknown default:
            return "camera.permission.unknown".localized
        }
    }
    
    func requestPermission() async -> Bool {
        guard authorizationStatus == .notDetermined else {
            return authorizationStatus == .authorized
        }
        
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
        return granted
    }
    
    func checkPermission() {
        Task { @MainActor in
            self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
    
    static func isCameraAvailable() -> Bool {
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}