//
//  CameraPreview.swift
//  rCamera
//
//  Created by Gabriel on 9/26/26.
//

import Foundation
import SwiftUI
import AVFoundation

class VideoPreviewView: UIView {
    
    // override layerClass from AnyClass to AVCaptureVideoPreview.self
    override class var layerClass: AnyClass { return AVCaptureVideoPreviewLayer.self }
    // forced casting
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreview: UIViewRepresentable {
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        
        let view = VideoPreviewView()
        
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
    }
}
