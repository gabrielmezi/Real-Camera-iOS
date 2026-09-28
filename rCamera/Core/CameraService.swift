//
//  CameraService.swift
//  rCamera
//
//  Created by Gabriel on 9/26/26.
//

import Foundation
import AVFoundation
import CoreMedia
import Photos
import CoreImage
import UIKit

class CameraService: NSObject {
    let captureSession = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    var activeDevice: AVCaptureDevice?
    var videoDeviceInput: AVCaptureDeviceInput?
    
    var minISO: Float { activeDevice?.activeFormat.minISO ?? 33.0 }
    var maxISO: Float { activeDevice?.activeFormat.maxISO ?? 2200.0 }
    
    var minDuration: CMTime { activeDevice?.activeFormat.minExposureDuration ?? CMTimeMake(value: 1, timescale: 10000) }
    var maxDuration: CMTime { activeDevice?.activeFormat.maxExposureDuration ?? CMTimeMake(value: 1, timescale: 3) }
    
    var isFlashOn: Bool = false
    private let albumName = "Real Camera"
    
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false, .cacheIntermediates: false])
    
    func setupSession() {
        captureSession.beginConfiguration()
        
        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
        }
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Error (1): Video device not found. Core/CameraService")
            captureSession.commitConfiguration()
            return
        }
        
        self.activeDevice = videoDevice
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice), captureSession.canAddInput(videoInput) else {
            print("Error (2): Couldn't add video input. Core/CameraService")
            captureSession.commitConfiguration()
            return
        }
        
        self.videoDeviceInput = videoInput
        self.captureSession.addInput(videoInput)
        
        guard captureSession.canAddOutput(photoOutput) else {
            print("Error (3): Couldn't add the photo output. Core/CameraService")
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.addOutput(photoOutput)
        captureSession.commitConfiguration()
    }
    
    func start() {
        guard !captureSession.isRunning else {return}
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func stop() {
        guard captureSession.isRunning else {return}
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    private func updateVideoOrientation(for connection: AVCaptureConnection) {
            let deviceOrientation = UIDevice.current.orientation
            
            if #available(iOS 17.0, *) {
                switch deviceOrientation {
                case .portrait:             connection.videoRotationAngle = 90.0
                case .landscapeRight:       connection.videoRotationAngle = 0.0
                case .landscapeLeft:        connection.videoRotationAngle = 180.0
                case .portraitUpsideDown:   connection.videoRotationAngle = 270.0
                default:                    connection.videoRotationAngle = 90.0
                }
            } else {
                // ios 16 and below
                switch deviceOrientation {
                case .portrait:             connection.videoOrientation = .portrait
                case .landscapeRight:       connection.videoOrientation = .landscapeLeft
                case .landscapeLeft:        connection.videoOrientation = .landscapeRight
                case .portraitUpsideDown:   connection.videoOrientation = .portraitUpsideDown
                default:                    connection.videoOrientation = .portrait
                }
            }
        }
    
    func capturePhoto() {
        if let connection = photoOutput.connection(with: .video) {
            updateVideoOrientation(for: connection)
        }
        
        let settings: AVCapturePhotoSettings
        if let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first {
            settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
        } else {
            settings = AVCapturePhotoSettings()
        }
        
        if photoOutput.maxPhotoQualityPrioritization != .speed {
            settings.photoQualityPrioritization = .speed
        }
        
        settings.flashMode = isFlashOn ? .on : .off
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func getOrCreateAlbum(completion: @escaping (PHAssetCollection?) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let album = collection.firstObject {
            completion(album)
        } else {
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumName)
            }) { success, _ in
                if success {
                    let newCollection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
                    completion(newCollection.firstObject)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    private func saveToPhotoLibrary(imageData: Data) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                print("Error (9): Unauthorized to save photos.")
                return
            }
            
            self.getOrCreateAlbum { album in
                PHPhotoLibrary.shared().performChanges({
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: imageData, options: nil)
                    
                    if let album = album, let placeholder = creationRequest.placeholderForCreatedAsset {
                        let addAssetRequest = PHAssetCollectionChangeRequest(for: album)
                        addAssetRequest?.addAssets([placeholder] as NSArray)
                    }
                }) { success, error in
                    if success {
                        print("Photo saved to \(self.albumName)")
                    } else if let error = error {
                        print("Error saving photo: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func developRawToPureJPEG(rawData: Data) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let rawFilter = CIRAWFilter(imageData: rawData, identifierHint: nil) else { return }
            
            rawFilter.luminanceNoiseReductionAmount = 0.0
            rawFilter.colorNoiseReductionAmount = 0.0
            rawFilter.detailAmount = 0.0
            rawFilter.localToneMapAmount = 0.0
            
            guard let outputImage = rawFilter.outputImage,
                  let cgImage = self.ciContext.createCGImage(outputImage, from: outputImage.extent) else { return }
            
            let uiImage = UIImage(cgImage: cgImage)
            guard let pureJpegData = uiImage.jpegData(compressionQuality: 0.95) else { return }
            self.saveToPhotoLibrary(imageData: pureJpegData)
        }
    }
    
    func setManualExposure(iso: Float, duration: CMTime) {
        guard let device = activeDevice else { return }
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: duration, iso: iso) { _ in }
            device.unlockForConfiguration()
        } catch {
            print("Error (5): Couldn't lock the lens for manual control")
        }
    }
    
    func setExposureMode(isManual: Bool, iso: Float, duration: Double) {
        guard let activeDevice = activeDevice else { return }
        do {
            try activeDevice.lockForConfiguration()
            if isManual {
                let clampedISO = min(max(iso, activeDevice.activeFormat.minISO), activeDevice.activeFormat.maxISO)
                let clampedDuration = min(max(duration, CMTimeGetSeconds(activeDevice.activeFormat.minExposureDuration)), CMTimeGetSeconds(activeDevice.activeFormat.maxExposureDuration))
                let timeDuration = CMTime(seconds: clampedDuration, preferredTimescale: 1_000_000)
                activeDevice.setExposureModeCustom(duration: timeDuration, iso: clampedISO, completionHandler: nil)
            } else {
                if activeDevice.isExposureModeSupported(.continuousAutoExposure) {
                    activeDevice.exposureMode = .continuousAutoExposure
                }
            }
            activeDevice.unlockForConfiguration()
        } catch {
            print("Error al ajustar la exposición: \(error)")
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error (6): Capture failed - \(error.localizedDescription)")
            return
        }
        guard let photoData = photo.fileDataRepresentation() else { return }
        if photo.isRawPhoto {
            developRawToPureJPEG(rawData: photoData)
        } else {
            saveToPhotoLibrary(imageData: photoData)
        }
    }
}
