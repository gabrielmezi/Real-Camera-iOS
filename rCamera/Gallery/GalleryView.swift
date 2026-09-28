//
//  GalleryView.swift
//  rCamera
//
//  Created by Gabriel on 9/27/26.
//

import SwiftUI
import Photos

struct GalleryView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var images: [(asset: PHAsset, image: UIImage)] = []
    @State private var currentIndex: Int = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if images.isEmpty {
                    Text("No hay fotos en Real Camera")
                        .foregroundColor(.gray)
                } else {
                    TabView(selection: $currentIndex) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Image(uiImage: images[index].image)
                                .resizable()
                                .scaledToFit()
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark").foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 20) {
                        if !images.isEmpty {
                            ShareLink(item: Image(uiImage: images[currentIndex].image),
                                      preview: SharePreview("Foto", image: Image(uiImage: images[currentIndex].image))) {
                                Image(systemName: "square.and.arrow.up").foregroundColor(.white)
                            }
                            
                            Button(action: deleteCurrentPhoto) {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .onAppear(perform: loadPhotos)
        }
    }
    
    private func loadPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", "Real Camera")
        let album = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions).firstObject
        
        guard let targetAlbum = album else { return }
        
        let assetOptions = PHFetchOptions()
        assetOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(in: targetAlbum, options: assetOptions)
        
        var loadedImages: [(PHAsset, UIImage)] = []
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        
        assets.enumerateObjects { (asset, _, _) in
            imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: requestOptions) { image, _ in
                if let image = image {
                    loadedImages.append((asset, image))
                }
            }
        }
        self.images = loadedImages
        self.currentIndex = 0
    }
    
    private func deleteCurrentPhoto() {
        guard !images.isEmpty else { return }
        let assetToDelete = images[currentIndex].asset
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([assetToDelete] as NSArray)
        }) { success, error in
            if success {
                DispatchQueue.main.async {
                    images.remove(at: currentIndex)
                    if currentIndex >= images.count {
                        currentIndex = max(0, images.count - 1)
                    }
                }
            }
        }
    }
}
