//
//  ImageCache.swift
//  Pact
//

import SwiftUI

// MARK: - Cache

/// Lightweight in-memory image cache backed by NSCache.
/// NSCache automatically evicts entries under memory pressure, so there is
/// no manual cleanup needed.  Since proof photos are one-per-user-per-day
/// the total footprint is tiny (team size × compressed JPEG size).
final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 100          // max 100 images in memory
        c.totalCostLimit = 50 * 1024 * 1024  // 50 MB ceiling
        return c
    }()

    private init() {}

    func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        // Cost = compressed byte count (approximate; UIImage doesn't expose
        // decoded size cheaply, so we use the JPEG data size as a proxy).
        let cost = image.jpegData(compressionQuality: 1)?.count ?? 0
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

// MARK: - CachedProofImage

/// Drop-in replacement for `AsyncImage` that caches downloaded images in
/// `ImageCache.shared`.  Because the cache is app-level it survives view
/// re-creation (e.g. tab switches), so the image is displayed immediately
/// on subsequent visits without a spinner flash.
struct CachedProofImage: View {
    let urlString: String?
    var height: CGFloat = 260
    var cornerRadius: CGFloat = 14

    @State private var loadedImage: UIImage? = nil

    /// Synchronous cache hit — evaluated during the render pass so there is
    /// never even a one-frame gap before the cached image appears.
    private var cachedImage: UIImage? {
        guard let urlString else { return nil }
        return ImageCache.shared.get(urlString)
    }

    var body: some View {
        let display = loadedImage ?? cachedImage

        Group {
            if let display {
                Image(uiImage: display)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else if urlString != nil {
                // Still loading — show spinner placeholder
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(white: 0.94))
                    .frame(height: height)
                    .overlay { ProgressView().tint(Color(white: 0.55)) }
            } else {
                // No URL at all — static placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(white: 0.94))
                        .frame(height: height)
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(white: 0.70))
                }
            }
        }
        .task(id: urlString) {
            await fetchIfNeeded()
        }
    }

    private func fetchIfNeeded() async {
        guard let urlString, let url = URL(string: urlString) else { return }

        // Already cached — set state so SwiftUI tracks it (cachedImage handles
        // the display, but keeping loadedImage in sync avoids a second pass).
        if let cached = ImageCache.shared.get(urlString) {
            loadedImage = cached
            return
        }

        // Download, decode, and cache.
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else { return }

        ImageCache.shared.set(uiImage, for: urlString)
        loadedImage = uiImage
    }
}
