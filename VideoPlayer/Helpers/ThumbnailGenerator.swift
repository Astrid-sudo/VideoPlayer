//
//  ThumbnailGenerator.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import AVFoundation
import UIKit

class ThumbnailGenerator {
    static let shared = ThumbnailGenerator()

    private var cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 50 // Cache up to 50 thumbnails
    }

    func generateThumbnail(from urlString: String) async -> UIImage? {
        print("[Thumbnail] 🖼 Generating thumbnail for: \(urlString)")

        // Check cache first
        if let cachedImage = cache.object(forKey: urlString as NSString) {
            print("[Thumbnail] ✅ Found cached thumbnail")
            return cachedImage
        }

        guard let url = URL(string: urlString) else {
            print("[Thumbnail] ❌ Invalid URL: \(urlString)")
            return nil
        }

        // Use AVPlayer-based approach (方案 2) - works better for HLS
        print("[Thumbnail] 🎬 Using AVPlayer screenshot method for HLS stream")

        if let thumbnail = await generateThumbnailUsingPlayer(url: url) {
            // Cache the thumbnail
            cache.setObject(thumbnail, forKey: urlString as NSString)
            print("[Thumbnail] ✅ Thumbnail generated successfully using AVPlayer")
            return thumbnail
        }

        print("[Thumbnail] ❌ Failed to generate thumbnail")
        return nil
    }

    private func generateThumbnailUsingPlayer(url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                print("[Thumbnail] 🎥 Using AVPlayerItemVideoOutput method...")

                // 建立 player
                let player = AVPlayer(url: url)

                guard let playerItem = player.currentItem else {
                    print("[Thumbnail] ❌ No player item")
                    continuation.resume(returning: nil)
                    return
                }

                // 建立 video output
                let settings: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                let output = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
                playerItem.add(output)

                // Seek 到 12 秒處
                let targetTime = CMTime(seconds: 12.0, preferredTimescale: 600)
                print("[Thumbnail] ⏩ Seeking to 12.0s...")

                player.seek(to: targetTime, toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600),
                           toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600)) { finished in
                    guard finished else {
                        print("[Thumbnail] ⚠️ Seek did not finish")
                        continuation.resume(returning: nil)
                        return
                    }

                    print("[Thumbnail] ✅ Seek completed, playing to generate frame...")
                    player.play()

                    // 輪詢檢查 pixel buffer（最多等待 5 秒）
                    var attemptCount = 0
                    let maxAttempts = 25 // 25 x 0.2s = 5 秒

                    func tryExtractFrame() {
                        attemptCount += 1
                        let currentTime = player.currentTime()

                        if output.hasNewPixelBuffer(forItemTime: currentTime),
                           let pixelBuffer = output.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) {

                            print("[Thumbnail] 📸 Frame available at attempt \(attemptCount), time: \(CMTimeGetSeconds(currentTime))s")

                            // 從 pixel buffer 建立圖片
                            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                            let context = CIContext()

                            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                                let image = UIImage(cgImage: cgImage)

                                // 檢查亮度
                                if let dataProvider = cgImage.dataProvider,
                                   let data = dataProvider.data,
                                   let bytes = CFDataGetBytePtr(data) {
                                    var sum: UInt64 = 0
                                    let sampleSize = min(1000, cgImage.width * cgImage.height)
                                    for i in 0..<sampleSize {
                                        sum += UInt64(bytes[i * 4])
                                    }
                                    let average = sum / UInt64(sampleSize)
                                    print("[Thumbnail] 🎨 Image average brightness: \(average)/255")
                                }

                                print("[Thumbnail] ✅ Frame extracted successfully: \(image.size)")

                                // 清理
                                player.pause()
                                player.replaceCurrentItem(with: nil)

                                continuation.resume(returning: image)
                            } else {
                                print("[Thumbnail] ❌ Failed to create CGImage")
                                player.pause()
                                player.replaceCurrentItem(with: nil)
                                continuation.resume(returning: nil)
                            }
                        } else if attemptCount < maxAttempts {
                            // 繼續等待
                            if attemptCount % 5 == 0 {
                                print("[Thumbnail] ⏳ Waiting for frame... (attempt \(attemptCount)/\(maxAttempts))")
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                tryExtractFrame()
                            }
                        } else {
                            print("[Thumbnail] ❌ Timeout: No pixel buffer after \(maxAttempts) attempts")
                            player.pause()
                            player.replaceCurrentItem(with: nil)
                            continuation.resume(returning: nil)
                        }
                    }

                    // 開始首次嘗試（等待 0.5 秒後）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        tryExtractFrame()
                    }
                }
            }
        }
    }

    private func generateThumbnailAsync(imageGenerator: AVAssetImageGenerator) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)

            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { requestedTime, cgImage, actualTime, result, error in
                if let error = error {
                    print("[Thumbnail] ❌ Async generation error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }

                if let cgImage = cgImage {
                    let thumbnail = UIImage(cgImage: cgImage)
                    print("[Thumbnail] ✅ Async thumbnail generated successfully")
                    continuation.resume(returning: thumbnail)
                } else {
                    print("[Thumbnail] ❌ No image generated")
                    continuation.resume(throwing: NSError(domain: "ThumbnailGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image generated"]))
                }
            }
        }
    }
}
