import Foundation
import UIKit
import CoreVideo
import CoreImage
import MediaPipeTasksVision

@objc public class SegmentationProcessor: NSObject {
    
    private var imageSegmenter: ImageSegmenter?
    private var statusMessage: String = "Initializing..."
    
    // Confidence thresholds (Processor returns PERSON confidence, opposite of MLKit's background confidence)
    private let confidenceThresholdHigh: Float = 0.5
    private let confidenceThresholdLow: Float = 0.3
    
    // Mask erosion radius (disabled to match MLKit)
    private var maskErosionRadius: Float = 0.0
    
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
            options.shouldOutputCategoryMask = false
            options.shouldOutputConfidenceMasks = true  // Use confidence masks like MLKit
            
            if let modelPath = Bundle.main.path(forResource: "selfie_segmenter", ofType: "tflite") {
                options.baseOptions.modelAssetPath = modelPath
                    imageSegmenter = try ImageSegmenter(options: options)
                statusMessage = "✅ Processor initialized with custom model"
                    return
            }
            
            // Fallback to default model
            let fallbackOptions = ImageSegmenterOptions()
            fallbackOptions.runningMode = .image
            imageSegmenter = try ImageSegmenter(options: fallbackOptions)
            statusMessage = "✅ Processor initialized with default model"
            
        } catch {
            statusMessage = "⚠️ Failed to initialize Processor: \(error.localizedDescription)"
        }
    }
   
   @objc public func getStatusMessage() -> String {
       return statusMessage
   }
    
    public func processSampleBuffer(_ sampleBuffer: CVPixelBuffer, background: UIImage?, completion: @escaping (CVPixelBuffer?) -> Void) {
       
       guard let segmenter = imageSegmenter else {
           completion(sampleBuffer)
           return
       }
       
       do {
           let mpImage = try MPImage(pixelBuffer: sampleBuffer)
            let result = try segmenter.segment(videoFrame: mpImage, timestampInMilliseconds: Int(Date().timeIntervalSince1970 * 1000))
            
            // Use confidence masks instead of category masks for better quality
            guard let confidenceMasks = result.confidenceMasks, !confidenceMasks.isEmpty else {
               completion(sampleBuffer)
               return
            }
            
            // Processor returns multiple masks, first one is usually person/background
            let mask = confidenceMasks[0]
            
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
                    maskData: mask.float32Data,
                    maskWidth: mask.width,
                    maskHeight: mask.height,
                    backgroundBuffer: backgroundBuffer,
                    outputBuffer: output
                )
            } else {
                applyBlurEffect(
                    personBuffer: sampleBuffer,
                    maskData: mask.float32Data,
                    maskWidth: mask.width,
                    maskHeight: mask.height,
                    outputBuffer: output
                )
            }
            
            completion(output)
            
        } catch {
            completion(sampleBuffer)
        }
    }
    
    // Optimized background pixel buffer creation using UIUtilities
    private func createBackgroundPixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
       return UIUtilities.createImageBuffer(from: image, size: size, shouldRotateAndMirror: true)
   }
   
    // Optimized composite using CIFilter blend modes with confidence thresholds (matching MLKit)
    private func compositeWithBackground(
        personBuffer: CVPixelBuffer,
        maskData: UnsafePointer<Float32>,
        maskWidth: Int,
        maskHeight: Int,
        backgroundBuffer: CVPixelBuffer,
        outputBuffer: CVPixelBuffer
    ) {
        let width = CVPixelBufferGetWidth(personBuffer)
        let height = CVPixelBufferGetHeight(personBuffer)
        
        // Try GPU-accelerated path first
        if let maskCIImage = createMaskCIImage(from: maskData, 
                                                maskWidth: maskWidth, 
                                                maskHeight: maskHeight, 
                                                targetWidth: width, 
                                                targetHeight: height),
           let blendFilter = CIFilter(name: "CIBlendWithMask") {
            
            let personImage = CIImage(cvPixelBuffer: personBuffer)
            let backgroundImage = CIImage(cvPixelBuffer: backgroundBuffer)
            
            blendFilter.setValue(personImage, forKey: kCIInputImageKey)
            blendFilter.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)
            blendFilter.setValue(maskCIImage, forKey: kCIInputMaskImageKey)
            
            if let compositedImage = blendFilter.outputImage {
                let bounds = CGRect(x: 0, y: 0, width: width, height: height)
                ciContext.render(compositedImage, to: outputBuffer, bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
                return
            }
        }
        
        // Fallback to CPU path using shared utility
        UIUtilities.compositeBuffers(
            personBuffer: personBuffer,
            backgroundBuffer: backgroundBuffer,
            outputBuffer: outputBuffer,
            maskData: maskData,
            maskWidth: maskWidth,
            maskHeight: maskHeight,
            confidenceThresholds: (low: confidenceThresholdLow, high: confidenceThresholdHigh)
        )
    }
    
    // Creates mask CIImage from Float32 confidence values with thresholds (like MLKit)
    private func createMaskCIImage(from maskData: UnsafePointer<Float32>, 
                                   maskWidth: Int, 
                                   maskHeight: Int, 
                                   targetWidth: Int, 
                                   targetHeight: Int) -> CIImage? {
        // Convert Float32 confidence to UInt8 with thresholds for better segmentation
        let pixelCount = maskWidth * maskHeight
        var uint8Data = [UInt8](repeating: 0, count: pixelCount)
        
        for i in 0..<pixelCount {
            let confidence = maskData[i]  // PERSON confidence (Processor)
            
            // Processor returns PERSON confidence (opposite of MLKit's background confidence)
            if confidence > confidenceThresholdHigh {
                // Definitely person (high person confidence)
                uint8Data[i] = 255  // Person = white
            } else if confidence < confidenceThresholdLow {
                // Definitely background (low person confidence)
                uint8Data[i] = 0    // Background = black
            } else {
                // Transition zone: interpolate smoothly
                 let normalized = (confidence - confidenceThresholdLow) /// (confidenceThresholdHigh - confidenceThresholdLow)
                uint8Data[i] = UInt8(normalized * 255.0)  // Higher confidence = more person
            }
        }
        
        // Create mask image from processed data
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGImageAlphaInfo.none.rawValue
        
        guard let provider = CGDataProvider(data: Data(uint8Data) as CFData),
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
        
        // Apply erosion to reduce false positives (shrink mask to keep only confident regions)
        if maskErosionRadius > 0 {
            maskImage = applyMaskErosion(maskImage, radius: maskErosionRadius) ?? maskImage
        }
        
        // Apply Gaussian blur to mask edges for smoother compositing (like MLKit's soft blending)
        if let blurFilter = CIFilter(name: "CIGaussianBlur") {
            blurFilter.setValue(maskImage, forKey: kCIInputImageKey)
            blurFilter.setValue(2.0, forKey: kCIInputRadiusKey)  // Soft edge transition
            if let blurredMask = blurFilter.outputImage {
                maskImage = blurredMask
            }
        }
        
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
    
    // Apply morphological erosion to mask (shrinks mask to reduce false positives)
    private func applyMaskErosion(_ maskImage: CIImage, radius: Float) -> CIImage? {
        // Use CIMorphologyMinimum (erosion) to shrink white regions
        guard let morphologyFilter = CIFilter(name: "CIMorphologyMinimum") else {
            return maskImage
        }
        
        morphologyFilter.setValue(maskImage, forKey: kCIInputImageKey)
        morphologyFilter.setValue(radius, forKey: kCIInputRadiusKey)
        
        return morphologyFilter.outputImage
    }
    
    
    // Optimized blur effect using CIFilter with confidence thresholds
    private func applyBlurEffect(
        personBuffer: CVPixelBuffer,
        maskData: UnsafePointer<Float32>,
        maskWidth: Int,
        maskHeight: Int,
        outputBuffer: CVPixelBuffer
    ) {
        let width = CVPixelBufferGetWidth(personBuffer)
        let height = CVPixelBufferGetHeight(personBuffer)
        
        // Try GPU-accelerated path first
        if let maskCIImage = createMaskCIImage(from: maskData, 
                                                maskWidth: maskWidth, 
                                                maskHeight: maskHeight, 
                                                targetWidth: width, 
                                                targetHeight: height),
           let blurFilter = CIFilter(name: "CIGaussianBlur"),
           let blendFilter = CIFilter(name: "CIBlendWithMask") {
            
            let personImage = CIImage(cvPixelBuffer: personBuffer)
            
            blurFilter.setValue(personImage, forKey: kCIInputImageKey)
            blurFilter.setValue(20.0, forKey: kCIInputRadiusKey)
            
            if let blurredImage = blurFilter.outputImage {
                blendFilter.setValue(personImage, forKey: kCIInputImageKey)
                blendFilter.setValue(blurredImage, forKey: kCIInputBackgroundImageKey)
                blendFilter.setValue(maskCIImage, forKey: kCIInputMaskImageKey)
                
                if let compositedImage = blendFilter.outputImage {
                    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
                    ciContext.render(compositedImage, to: outputBuffer, bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
                    return
                }
            }
        }
        
        // Fallback to CPU path
        applyBlurEffectFallback(personBuffer: personBuffer, 
                               maskData: maskData, 
                               maskWidth: maskWidth, 
                               maskHeight: maskHeight, 
                               outputBuffer: outputBuffer)
    }
    
    // Fallback to pixel-by-pixel blending for blur effect with confidence thresholds
    private func applyBlurEffectFallback(
        personBuffer: CVPixelBuffer,
        maskData: UnsafePointer<Float32>,
        maskWidth: Int,
        maskHeight: Int,
        outputBuffer: CVPixelBuffer
    ) {
        let width = CVPixelBufferGetWidth(personBuffer)
        let height = CVPixelBufferGetHeight(personBuffer)
        
        // Create blurred version
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return }
        let personImage = CIImage(cvPixelBuffer: personBuffer)
        blurFilter.setValue(personImage, forKey: kCIInputImageKey)
        blurFilter.setValue(20.0, forKey: kCIInputRadiusKey)
        
        guard let blurredImage = blurFilter.outputImage else { return }
        
        var blurredBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, Self.pixelBufferAttrs, &blurredBuffer)
        
        guard status == kCVReturnSuccess, let blurred = blurredBuffer else { return }
        
        ciContext.render(blurredImage, to: blurred, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: CGColorSpaceCreateDeviceRGB())
        
        // Use shared utility for compositing
        UIUtilities.compositeBuffers(
            personBuffer: personBuffer,
            backgroundBuffer: blurred,
            outputBuffer: outputBuffer,
            maskData: maskData,
            maskWidth: maskWidth,
            maskHeight: maskHeight,
            confidenceThresholds: (low: confidenceThresholdLow, high: confidenceThresholdHigh)
        )
    }
}
