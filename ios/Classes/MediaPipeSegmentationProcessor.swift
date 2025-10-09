import Foundation
import UIKit
import CoreVideo
import CoreImage
import MediaPipeTasksVision

@objc public class MediaPipeSegmentationProcessor: NSObject {
    
    private var imageSegmenter: ImageSegmenter?
    private var statusMessage: String = "Initializing..."
    
    // Reusable pixel buffer attributes
    private static let pixelBufferAttrs: CFDictionary = [
        kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
        kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!
    ] as CFDictionary
    
    // Reusable CIContext for better performance
    private lazy var ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .priorityRequestLow: false
        ]
        return CIContext(options: options)
    }()
   
   @objc public override init() {
       super.init()
       setupImageSegmenter()
   }
   
    public func setupImageSegmenter() {
        do {
            let options = ImageSegmenterOptions()
            options.runningMode = .video
            options.shouldOutputCategoryMask = true
            options.shouldOutputConfidenceMasks = false
            
            if let modelPath = Bundle.main.path(forResource: "selfie_segmenter", ofType: "tflite") {
                options.baseOptions.modelAssetPath = modelPath
                    imageSegmenter = try ImageSegmenter(options: options)
                statusMessage = "✅ MediaPipe initialized with custom model"
                    return
            }
            
            // Fallback to default model
            let fallbackOptions = ImageSegmenterOptions()
            fallbackOptions.runningMode = .image
            imageSegmenter = try ImageSegmenter(options: fallbackOptions)
            statusMessage = "✅ MediaPipe initialized with default model"
            
        } catch {
            statusMessage = "⚠️ Failed to initialize MediaPipe: \(error.localizedDescription)"
        }
    }
   
   @objc public func getStatusMessage() -> String {
       return statusMessage
   }
    
    @objc public func processSampleBuffer(_ sampleBuffer: CVPixelBuffer, background: UIImage?, completion: @escaping (CVPixelBuffer?) -> Void) {
       
       guard let segmenter = imageSegmenter else {
           completion(sampleBuffer)
           return
       }
       
       do {
           let mpImage = try MPImage(pixelBuffer: sampleBuffer)
            let result = try segmenter.segment(videoFrame: mpImage, timestampInMilliseconds: Int(Date().timeIntervalSince1970 * 1000))
            
            guard let categoryMask = result.categoryMask else {
           completion(sampleBuffer)
           return
            }
            
            let width = CVPixelBufferGetWidth(sampleBuffer)
            let height = CVPixelBufferGetHeight(sampleBuffer)
            let pixelFormat = CVPixelBufferGetPixelFormatType(sampleBuffer)
            
            var outputBuffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, Self.pixelBufferAttrs, &outputBuffer)
            
            guard status == kCVReturnSuccess, let output = outputBuffer else {
                completion(sampleBuffer)
           return
       }
       
            if let background = background {
                guard let backgroundBuffer = createBackgroundPixelBuffer(from: background, size: CGSize(width: width, height: height)) else {
                    completion(sampleBuffer)
           return
       }
       
                compositeWithBackground(
                    personBuffer: sampleBuffer,
                    maskData: categoryMask.uint8Data,
                    maskWidth: categoryMask.width,
                    maskHeight: categoryMask.height,
                    backgroundBuffer: backgroundBuffer,
                    outputBuffer: output
                )
            } else {
                applyBlurEffect(
                    personBuffer: sampleBuffer,
                    maskData: categoryMask.uint8Data,
                    maskWidth: categoryMask.width,
                    maskHeight: categoryMask.height,
                    outputBuffer: output
                )
            }
            
            completion(output)
            
        } catch {
            completion(sampleBuffer)
        }
    }
    
    // Optimized background pixel buffer creation
    private func createBackgroundPixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
       var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, Self.pixelBufferAttrs, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
       
       CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
       defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }
       
       let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                              width: Int(size.width),
                              height: Int(size.height),
                              bitsPerComponent: 8,
                              bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                              space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        context?.saveGState()
        context?.translateBy(x: size.width / 2, y: size.height / 2)
        context?.rotate(by: .pi / 2)
        context?.scaleBy(x: -1.0, y: 1.0)
        
        let drawRect = CGRect(x: -size.height / 2, y: -size.width / 2, width: size.height, height: size.width)
       context?.draw(image.cgImage!, in: drawRect)
        context?.restoreGState()
       
       return buffer
   }
   
    // Optimized composite using CIFilter blend modes for smooth edges (similar to Android Canvas)
    private func compositeWithBackground(
        personBuffer: CVPixelBuffer,
        maskData: UnsafePointer<UInt8>,
        maskWidth: Int,
        maskHeight: Int,
        backgroundBuffer: CVPixelBuffer,
        outputBuffer: CVPixelBuffer
    ) {
        let width = CVPixelBufferGetWidth(personBuffer)
        let height = CVPixelBufferGetHeight(personBuffer)
        
        // Convert to CIImages for GPU-accelerated processing
        let personImage = CIImage(cvPixelBuffer: personBuffer)
        let backgroundImage = CIImage(cvPixelBuffer: backgroundBuffer)
        
        // Create mask CIImage with high quality scaling
        guard let maskCIImage = createMaskCIImage(from: maskData, 
                                                  maskWidth: maskWidth, 
                                                  maskHeight: maskHeight, 
                                                  targetWidth: width, 
                                                  targetHeight: height) else {
            // Fallback if mask creation fails
            compositeWithBackgroundFallback(personBuffer: personBuffer, 
                                           maskData: maskData, 
                                           maskWidth: maskWidth, 
                                           maskHeight: maskHeight, 
                                           backgroundBuffer: backgroundBuffer, 
                                           outputBuffer: outputBuffer)
            return
        }
        
        // Invert mask: MediaPipe returns 0=background, 255=person, we need opposite for blending
        guard let invertFilter = CIFilter(name: "CIColorInvert") else { return }
        invertFilter.setValue(maskCIImage, forKey: kCIInputImageKey)
        guard let invertedMask = invertFilter.outputImage else { return }
        
        // Apply mask to person (keep only person pixels) - like Android's DST_IN
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return }
        blendFilter.setValue(personImage, forKey: kCIInputImageKey)
        blendFilter.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(invertedMask, forKey: kCIInputMaskImageKey)
        
        guard let compositedImage = blendFilter.outputImage else { return }
        
        // Render to output buffer with high quality
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        ciContext.render(compositedImage, to: outputBuffer, bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
    }
    
    // Creates mask CIImage with smooth scaling using Lanczos interpolation
    private func createMaskCIImage(from maskData: UnsafePointer<UInt8>, 
                                   maskWidth: Int, 
                                   maskHeight: Int, 
                                   targetWidth: Int, 
                                   targetHeight: Int) -> CIImage? {
        // Create mask image from raw data
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGImageAlphaInfo.none.rawValue
        
        guard let provider = CGDataProvider(data: Data(bytes: maskData, count: maskWidth * maskHeight) as CFData),
              let maskCGImage = CGImage(width: maskWidth,
                                       height: maskHeight,
                                       bitsPerComponent: 8,
                                       bitsPerPixel: 8,
                                       bytesPerRow: maskWidth,
                                       space: colorSpace,
                                       bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                                       provider: provider,
                                       decode: nil,
                                       shouldInterpolate: true,
                                       intent: .defaultIntent) else {
            return nil
        }
        
        var maskImage = CIImage(cgImage: maskCGImage)
        
        // Scale with high quality Lanczos algorithm (better than bilinear)
        let scaleX = CGFloat(targetWidth) / CGFloat(maskWidth)
        let scaleY = CGFloat(targetHeight) / CGFloat(maskHeight)
        
        guard let scaleFilter = CIFilter(name: "CILanczosScaleTransform") else {
            // Fallback to simple transform if Lanczos not available
            return maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        }
        
        scaleFilter.setValue(maskImage, forKey: kCIInputImageKey)
        scaleFilter.setValue(scaleX, forKey: kCIInputScaleKey)
        scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        
        return scaleFilter.outputImage
    }
    
    // Fallback to pixel-by-pixel blending if Core Graphics approach fails
    private func compositeWithBackgroundFallback(
        personBuffer: CVPixelBuffer,
        maskData: UnsafePointer<UInt8>,
        maskWidth: Int,
        maskHeight: Int,
        backgroundBuffer: CVPixelBuffer,
        outputBuffer: CVPixelBuffer
    ) {
        let width = CVPixelBufferGetWidth(personBuffer)
        let height = CVPixelBufferGetHeight(personBuffer)
        
        CVPixelBufferLockBaseAddress(personBuffer, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(backgroundBuffer, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        defer {
            CVPixelBufferUnlockBaseAddress(personBuffer, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferUnlockBaseAddress(backgroundBuffer, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferUnlockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        let personBytesPerRow = CVPixelBufferGetBytesPerRow(personBuffer)
        var personAddress = CVPixelBufferGetBaseAddress(personBuffer)!.bindMemory(to: UInt8.self, capacity: personBytesPerRow * height)
        
        let backgroundBytesPerRow = CVPixelBufferGetBytesPerRow(backgroundBuffer)
        var backgroundAddress = CVPixelBufferGetBaseAddress(backgroundBuffer)!.bindMemory(to: UInt8.self, capacity: backgroundBytesPerRow * height)
        
        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
        var outputAddress = CVPixelBufferGetBaseAddress(outputBuffer)!.bindMemory(to: UInt8.self, capacity: outputBytesPerRow * height)
        
        // Scale factors for mask
        let scaleX = CGFloat(maskWidth) / CGFloat(width)
        let scaleY = CGFloat(maskHeight) / CGFloat(height)
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = x * 4
                
                // Sample mask with scaling
                let maskX = Int(CGFloat(x) * scaleX)
                let maskY = Int(CGFloat(y) * scaleY)
                let maskIndex = min(maskY * maskWidth + maskX, maskWidth * maskHeight - 1)
                let maskValue = CGFloat(maskData[maskIndex]) / 255.0
                
                // Composite pixels - INVERTED: MediaPipe 0 = background, >0 = person
                let personRatio = 1.0 - maskValue
                let backgroundRatio = maskValue
                
                outputAddress[pixelOffset] = UInt8(CGFloat(personAddress[pixelOffset]) * personRatio + CGFloat(backgroundAddress[pixelOffset]) * backgroundRatio)
                outputAddress[pixelOffset + 1] = UInt8(CGFloat(personAddress[pixelOffset + 1]) * personRatio + CGFloat(backgroundAddress[pixelOffset + 1]) * backgroundRatio)
                outputAddress[pixelOffset + 2] = UInt8(CGFloat(personAddress[pixelOffset + 2]) * personRatio + CGFloat(backgroundAddress[pixelOffset + 2]) * backgroundRatio)
                outputAddress[pixelOffset + 3] = UInt8(CGFloat(personAddress[pixelOffset + 3]) * personRatio + CGFloat(backgroundAddress[pixelOffset + 3]) * backgroundRatio)
            }
            
            personAddress += personBytesPerRow / MemoryLayout<UInt8>.size
            backgroundAddress += backgroundBytesPerRow / MemoryLayout<UInt8>.size
            outputAddress += outputBytesPerRow / MemoryLayout<UInt8>.size
        }
    }
    
    // Optimized blur effect using CIFilter blend modes
    private func applyBlurEffect(
        personBuffer: CVPixelBuffer,
        maskData: UnsafePointer<UInt8>,
        maskWidth: Int,
        maskHeight: Int,
        outputBuffer: CVPixelBuffer
    ) {
        let width = CVPixelBufferGetWidth(personBuffer)
        let height = CVPixelBufferGetHeight(personBuffer)
        
        // Create mask CIImage with high quality scaling
        guard let maskCIImage = createMaskCIImage(from: maskData, 
                                                  maskWidth: maskWidth, 
                                                  maskHeight: maskHeight, 
                                                  targetWidth: width, 
                                                  targetHeight: height) else {
            applyBlurEffectFallback(personBuffer: personBuffer, 
                                   maskData: maskData, 
                                   maskWidth: maskWidth, 
                                   maskHeight: maskHeight, 
                                   outputBuffer: outputBuffer)
            return
        }
        
        // Create person and blurred images
        let personImage = CIImage(cvPixelBuffer: personBuffer)
        
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return }
        blurFilter.setValue(personImage, forKey: kCIInputImageKey)
        blurFilter.setValue(20.0, forKey: kCIInputRadiusKey)
        guard let blurredImage = blurFilter.outputImage else { return }
        
        // Invert mask
        guard let invertFilter = CIFilter(name: "CIColorInvert") else { return }
        invertFilter.setValue(maskCIImage, forKey: kCIInputImageKey)
        guard let invertedMask = invertFilter.outputImage else { return }
        
        // Blend person (sharp) with blurred background
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return }
        blendFilter.setValue(personImage, forKey: kCIInputImageKey)
        blendFilter.setValue(blurredImage, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(invertedMask, forKey: kCIInputMaskImageKey)
        
        guard let compositedImage = blendFilter.outputImage else { return }
        
        // Render to output buffer
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        ciContext.render(compositedImage, to: outputBuffer, bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
    }
    
    // Fallback to pixel-by-pixel blending for blur effect
    private func applyBlurEffectFallback(
        personBuffer: CVPixelBuffer,
        maskData: UnsafePointer<UInt8>,
        maskWidth: Int,
        maskHeight: Int,
        outputBuffer: CVPixelBuffer
    ) {
        let width = CVPixelBufferGetWidth(personBuffer)
        let height = CVPixelBufferGetHeight(personBuffer)
        
        // Create blurred version
        let personImage = CIImage(cvPixelBuffer: personBuffer)
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return }
        blurFilter.setValue(personImage, forKey: kCIInputImageKey)
        blurFilter.setValue(20.0, forKey: kCIInputRadiusKey)
        
        guard let blurredImage = blurFilter.outputImage else { return }
        
        var blurredBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, Self.pixelBufferAttrs, &blurredBuffer)
        
        guard status == kCVReturnSuccess, let blurred = blurredBuffer else { return }
        
        ciContext.render(blurredImage, to: blurred, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: CGColorSpaceCreateDeviceRGB())
        
        CVPixelBufferLockBaseAddress(personBuffer, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(blurred, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        defer {
            CVPixelBufferUnlockBaseAddress(personBuffer, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferUnlockBaseAddress(blurred, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferUnlockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        let personBytesPerRow = CVPixelBufferGetBytesPerRow(personBuffer)
        var personAddress = CVPixelBufferGetBaseAddress(personBuffer)!.bindMemory(to: UInt8.self, capacity: personBytesPerRow * height)
        
        let blurredBytesPerRow = CVPixelBufferGetBytesPerRow(blurred)
        var blurredAddress = CVPixelBufferGetBaseAddress(blurred)!.bindMemory(to: UInt8.self, capacity: blurredBytesPerRow * height)
        
        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
        var outputAddress = CVPixelBufferGetBaseAddress(outputBuffer)!.bindMemory(to: UInt8.self, capacity: outputBytesPerRow * height)
        
        // Scale factors for mask
        let scaleX = CGFloat(maskWidth) / CGFloat(width)
        let scaleY = CGFloat(maskHeight) / CGFloat(height)
       
       for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = x * 4
                
                // Sample mask with scaling
                let maskX = Int(CGFloat(x) * scaleX)
                let maskY = Int(CGFloat(y) * scaleY)
                let maskIndex = min(maskY * maskWidth + maskX, maskWidth * maskHeight - 1)
                let maskValue = CGFloat(maskData[maskIndex]) / 255.0
                
                // Composite pixels - INVERTED: MediaPipe 0 = background, >0 = person
                let personRatio = 1.0 - maskValue
                let blurredRatio = maskValue
                
                outputAddress[pixelOffset] = UInt8(CGFloat(personAddress[pixelOffset]) * personRatio + CGFloat(blurredAddress[pixelOffset]) * blurredRatio)
                outputAddress[pixelOffset + 1] = UInt8(CGFloat(personAddress[pixelOffset + 1]) * personRatio + CGFloat(blurredAddress[pixelOffset + 1]) * blurredRatio)
                outputAddress[pixelOffset + 2] = UInt8(CGFloat(personAddress[pixelOffset + 2]) * personRatio + CGFloat(blurredAddress[pixelOffset + 2]) * blurredRatio)
                outputAddress[pixelOffset + 3] = UInt8(CGFloat(personAddress[pixelOffset + 3]) * personRatio + CGFloat(blurredAddress[pixelOffset + 3]) * blurredRatio)
            }
            
            personAddress += personBytesPerRow / MemoryLayout<UInt8>.size
            blurredAddress += blurredBytesPerRow / MemoryLayout<UInt8>.size
            outputAddress += outputBytesPerRow / MemoryLayout<UInt8>.size
        }
    }
}