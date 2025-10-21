import SwiftUI
import UIKit
import AVFoundation

struct PhotoCardView: View {
    @Binding var imageData: Data?
    @State private var showingCamera = false
    @State private var showingDeleteAlert = false
    @State private var showingPhotoViewer = false
    @State private var showingOverwriteAlert = false
    @State private var isCameraTransitioning = false
    @State private var isModalTransitioning = false
    @State private var showingImagePicker = false
    @State private var showingPermissionAlert = false
    @State private var showingCameraUnavailableAlert = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .camera
    @StateObject private var cameraService = CameraService()
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
            
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .onTapGesture {
                        guard !isModalTransitioning else { return }
                        showingPhotoViewer = true
                    }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("photo.placeholder".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        guard !isModalTransitioning else { return }
                        if imageData != nil {
                            isModalTransitioning = true
                            showingOverwriteAlert = true
                        } else {
                            handleCameraButtonTap()
                        }
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                    .padding(.trailing, 8)
                }
            }
        }
        .fullScreenCover(isPresented: $showingImagePicker, onDismiss: {
            isCameraTransitioning = false
        }) {
            ImagePickerView(imageData: $imageData, sourceType: imagePickerSourceType)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingPhotoViewer) {
            if let imageData = imageData {
                PhotoViewerView(imageData: imageData, onDelete: {
                    showingDeleteAlert = true
                    showingPhotoViewer = false
                })
                .preferredColorScheme(nil)
            }
        }
        .alert("photo.delete.title".localized, isPresented: $showingDeleteAlert) {
            Button("photo.delete.confirm".localized, role: .destructive) {
                imageData = nil
                Task {
                    try await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        isModalTransitioning = false
                    }
                }
            }
            Button("photo.delete.cancel".localized, role: .cancel) {
                Task {
                    try await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run {
                        isModalTransitioning = false
                    }
                }
            }
        } message: {
            Text("photo.delete.message".localized)
        }
        .alert("photo.overwrite.title".localized, isPresented: $showingOverwriteAlert) {
            Button("photo.overwrite.confirm".localized) {
                handleCameraButtonTap()
                Task {
                    try await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run {
                        isModalTransitioning = false
                    }
                }
            }
            Button("photo.overwrite.cancel".localized, role: .cancel) {
                Task {
                    try await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run {
                        isModalTransitioning = false
                    }
                }
            }
        } message: {
            Text("photo.overwrite.message".localized)
        }
        .alert("camera.unavailable.title".localized, isPresented: $showingCameraUnavailableAlert) {
            Button("photo.library.select".localized) {
                imagePickerSourceType = .photoLibrary
                showingImagePicker = true
            }
            Button("cancel".localized, role: .cancel) {}
        } message: {
            Text("camera.unavailable.message".localized)
        }
        .alert("camera.permission.denied.title".localized, isPresented: $showingPermissionAlert) {
            Button("settings.open".localized) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("cancel".localized, role: .cancel) {}
        } message: {
            Text("camera.permission.denied.message".localized)
        }
        .onChange(of: imageData) { _, newValue in
            if newValue != nil {
                isCameraTransitioning = true
            }
        }
        .onChange(of: showingDeleteAlert) { _, isShowing in
            if !isShowing && isModalTransitioning {
                Task {
                    try await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run {
                        isModalTransitioning = false
                    }
                }
            }
        }
        .onChange(of: showingOverwriteAlert) { _, isShowing in
            if !isShowing && isModalTransitioning {
                Task {
                    try await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run {
                        isModalTransitioning = false
                    }
                }
            }
        }
    }
    
    private func handleCameraButtonTap() {
        if !CameraService.isCameraAvailable() {
            showingCameraUnavailableAlert = true
            return
        }
        
        cameraService.checkPermission()
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .notDetermined:
            Task { @MainActor in
                let granted = await cameraService.requestPermission()
                if granted {
                    imagePickerSourceType = .camera
                    showingImagePicker = true
                }
            }
        case .authorized:
            imagePickerSourceType = .camera
            showingImagePicker = true
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            showingPermissionAlert = true
        }
    }
}

struct PhotoViewerView: View {
    let imageData: Data
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        onDelete()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.modalPresentationStyle = .fullScreen
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image: UIImage?
            if let editedImage = info[.editedImage] as? UIImage {
                image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                image = originalImage
            } else {
                image = nil
            }
            
            if let image = image {
                let processedImage = image.optimizedForReceipt()
                parent.imageData = processedImage.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    @Previewable @State var imageData: Data? = nil
    return PhotoCardView(imageData: $imageData)
        .padding()
}