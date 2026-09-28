//
//  CameraViewModel.swift
//  rCamera
//
//  Created by Gabriel on 9/27/26.
//

import Foundation
import AVFoundation
import CoreMedia

class CameraViewModel: ObservableObject {
    let cameraService = CameraService()
    
    @Published var currentISO: Float = 100.0
    @Published var currentDuration: Float = 1.0 / 5.0
    
    @Published var minISO: Float = 33.0
    @Published var maxISO: Float = 2200.0
    @Published var minDurationSeconds: Float = 1.0 / 10000.0
    @Published var maxDurationSeconds: Float = 1.0 / 3.0
    @Published var shutterSliderPercentage: Double = 0.5
    
    @Published var isManualMode: Bool = false
    @Published var isFlashOn: Bool = false
    @Published var showGallery: Bool = false
    
    func checkPermissionsAndStart() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            setupAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) {[weak self] granted in
                if granted { self?.setupAndStart() }
            }
        default:
            print("Error (4): Denied camera access")
        }
    }
    
    private func setupAndStart() {
        cameraService.setupSession()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.minISO = self.cameraService.minISO
            self.maxISO = self.cameraService.maxISO
            self.minDurationSeconds = Float(CMTimeGetSeconds(self.cameraService.minDuration))
            self.maxDurationSeconds = Float(CMTimeGetSeconds(self.cameraService.maxDuration))
            
            self.currentISO = self.minISO
            self.shutterSliderPercentage = 0.5
            self.updateExposure()
        }
        
        cameraService.start()
    }
    
    func applyManualExposure() {
        guard isManualMode else { return }
        
        let minD = Double(minDurationSeconds)
        let maxD = Double(maxDurationSeconds)
        let mappedDuration = minD * pow((maxD / minD), shutterSliderPercentage)
        self.currentDuration = Float(mappedDuration)
        
        let duration = CMTimeMakeWithSeconds(mappedDuration, preferredTimescale: 1_000_000)
        cameraService.setManualExposure(iso: currentISO, duration: duration)
    }
    
    func capturePhoto() {
        cameraService.isFlashOn = self.isFlashOn
        cameraService.capturePhoto()
    }
    
    func updateExposure() {
        if isManualMode {
            applyManualExposure()
        } else {
            cameraService.setExposureMode(isManual: false, iso: currentISO, duration: Double(currentDuration))
        }
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
        cameraService.isFlashOn = self.isFlashOn
    }
}
