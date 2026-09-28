//
//  CameraView.swift
//  rCamera
//
//  Created by Gabriel on 9/27/26.
//

import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // Flash
                    HStack {
                        Button(action: {
                            viewModel.toggleFlash()
                        }) {
                            Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 18))
                                .foregroundColor(viewModel.isFlashOn ? .yellow : .white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        Spacer()
                    }
                    
                    CameraPreview(session: viewModel.cameraService.captureSession)
                        .frame(width: geometry.size.width, height: geometry.size.width * (4.0 / 3.0))
                        .clipped()
                    
                    Spacer(minLength: 5)
        
                    VStack(spacing: 8) {
                        
                        // Botón AUTO/MAN
                        Button(action: {
                            viewModel.isManualMode.toggle()
                            viewModel.updateExposure()
                        }) {
                            Text(viewModel.isManualMode ? "MAN" : "AUTO")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(viewModel.isManualMode ? .yellow : .black)
                                .frame(width: 55, height: 24)
                                .background(viewModel.isManualMode ? Color(UIColor.darkGray) : Color.yellow)
                                .clipShape(Capsule())
                        }
                        
                        HStack(spacing: 8) {
                            Text("ISO: \(Int(viewModel.currentISO))")
                                .font(.system(size: 11)).foregroundColor(.white).monospacedDigit().frame(width: 45, alignment: .leading)
                            Slider(value: $viewModel.currentISO, in: viewModel.minISO...viewModel.maxISO)
                                .tint(.yellow).onChange(of: viewModel.currentISO) { _, _ in viewModel.applyManualExposure() }
                        }
                        
                        HStack(spacing: 8) {
                            Text("Shutter: 1/\(Int(1.0 / viewModel.currentDuration))")
                                .font(.system(size: 11)).foregroundColor(.white).monospacedDigit().frame(width: 65, alignment: .leading)
                            Slider(value: $viewModel.shutterSliderPercentage, in: 0.0...1.0)
                                .tint(.yellow).onChange(of: viewModel.shutterSliderPercentage) { _, _ in viewModel.applyManualExposure() }
                        }
                        .disabled(!viewModel.isManualMode)
                        .opacity(viewModel.isManualMode ? 1.0 : 0.3)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 5)
                    
                    HStack {
                        Button(action: {
                            viewModel.showGallery = true
                        }) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                        }
                        .padding(.leading, 25)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.capturePhoto()
                        }) {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                                .background(Circle().fill(.white))
                                .frame(width: 55, height: 55)
                        }
                        
                        Spacer()
                        
                        Color.clear.frame(width: 50, height: 50).padding(.trailing, 25)
                    }
                    .padding(.bottom, 10)
                }
            }
        }
        .onAppear {
            viewModel.checkPermissionsAndStart()
        }
        .sheet(isPresented: $viewModel.showGallery) {
            GalleryView()
        }
    }
}
