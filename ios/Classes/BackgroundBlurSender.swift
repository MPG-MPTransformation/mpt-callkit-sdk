import Foundation
import AVFoundation
import PortSIPVoIPSDK
import Vision
import CoreImage
import Accelerate

class BackgroundBlurSender: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let portSIPSDK: PortSIPSDK
    private let sessionId: Int
    private let useFrontCamera: Bool
    private let targetWidth: Int
    private let targetHeight: Int

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let captureQueue = DispatchQueue(label: "bg.blur.capture.queue")
    private let ciContext = CIContext(options: nil)

    private var segmentationRequest: VNGeneratePersonSegmentationRequest!
    private var lastFrameTime: CFTimeInterval = 0
    private var maxFPS: Double = 24.0

    init(portSIPSDK: PortSIPSDK, sessionId: Int, useFrontCamera: Bool, width: Int = 1280, height: Int = 720) {
        self.portSIPSDK = portSIPSDK
        self.sessionId = sessionId
        self.useFrontCamera = useFrontCamera
        self.targetWidth = width
        self.targetHeight = height
        super.init()

        segmentationRequest = VNGeneratePersonSegmentationRequest()
        if #available(iOS 15.0, *) {
            segmentationRequest.qualityLevel = .balanced
            segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
        }
        segmentationRequest.usesCPUOnly = false
    }

    func start() {
        configureCaptureSession()
        captureSession.startRunning()
    }

    func stop() {
        captureSession.stopRunning()
    }

    private func configureCaptureSession() {
        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.hd1280x720) {
            captureSession.sessionPreset = .hd1280x720
        } else {
            captureSession.sessionPreset = .high
        }

        guard let device = selectCamera(useFront: useFrontCamera) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            NSLog("BackgroundBlurSender - Failed to create device input: \(error)")
        }

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        if let connection = videoOutput.connection(with: .video) {
            connection.isVideoMirrored = useFrontCamera
            connection.videoOrientation = .portrait
        }
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)

        captureSession.commitConfiguration()
    }

    private func selectCamera(useFront: Bool) -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: useFront ? .front : .back) {
            try? device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.unlockForConfiguration()
            return device
        }
        return AVCaptureDevice.default(for: .video)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CACurrentMediaTime()
        if timestamp - lastFrameTime < (1.0 / maxFPS) {
            return
        }
        lastFrameTime = timestamp

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var maskPixelBuffer: CVPixelBuffer?
        do {
            let reqHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            try reqHandler.perform([segmentationRequest])
            if let result = segmentationRequest.results?.first as? VNPixelBufferObservation {
                maskPixelBuffer = result.pixelBuffer
            }
        } catch {
            NSLog("BackgroundBlurSender - Vision error: \(error)")
            return
        }

        guard let maskPB = maskPixelBuffer else { return }

        let sourceImage = CIImage(cvPixelBuffer: pixelBuffer)
        let blurred = sourceImage.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 10.0]).cropped(to: sourceImage.extent)
        let maskImage = CIImage(cvPixelBuffer: maskPB)
        let composited = sourceImage.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: blurred,
            kCIInputMaskImageKey: maskImage
        ])

        // Render to BGRA
        let outWidth = targetWidth
        let outHeight = targetHeight
        guard let bgraBuffer = createBGRA.pixelBuffer(width: outWidth, height: outHeight) else { return }
        ciContext.render(composited, to: bgraBuffer)

        // Convert BGRA CVPixelBuffer to I420 Data
        if let i420Data = Self.convertBGRAtoI420(bgraPixelBuffer: bgraBuffer) {
            // Send via PortSIP (Swift-renamed signature)
            _ = portSIPSDK.sendVideoStream(toRemote: Int(Int64(sessionId)), data: i420Data as NSData as Data, width: Int32(outWidth), height: Int32(outHeight))
        }
    }

    private static func convertBGRAtoI420(bgraPixelBuffer: CVPixelBuffer) -> Data? {
        CVPixelBufferLockBaseAddress(bgraPixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(bgraPixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(bgraPixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(bgraPixelBuffer)
        let height = CVPixelBufferGetHeight(bgraPixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(bgraPixelBuffer)

        let yPlaneSize = width * height
        let uPlaneSize = (width/2) * (height/2)
        let vPlaneSize = uPlaneSize

        var yData = Data(count: yPlaneSize)
        var uData = Data(count: uPlaneSize)
        var vData = Data(count: vPlaneSize)

        yData.withUnsafeMutableBytes { yPtr in
            uData.withUnsafeMutableBytes { uPtr in
                vData.withUnsafeMutableBytes { vPtr in
                    let yOut = yPtr.bindMemory(to: UInt8.self).baseAddress!
                    let uOut = uPtr.bindMemory(to: UInt8.self).baseAddress!
                    let vOut = vPtr.bindMemory(to: UInt8.self).baseAddress!

                    for j in 0..<height {
                        let rowPtr = base.advanced(by: j * bytesPerRow).assumingMemoryBound(to: UInt8.self)
                        var yIndex = j * width
                        for i in 0..<width {
                            let pixel = rowPtr.advanced(by: i * 4)
                            let b = Float(pixel[0])
                            let g = Float(pixel[1])
                            let r = Float(pixel[2])
                            // BT.601 full-range conversion
                            var yVal = (0.299 * r + 0.587 * g + 0.114 * b)
                            if yVal < 0 { yVal = 0 }
                            if yVal > 255 { yVal = 255 }
                            yOut[yIndex] = UInt8(yVal)
                            yIndex += 1
                        }
                    }

                    // U and V subsampling (2x2 average)
                    var uIndex = 0
                    var vIndex = 0
                    for j in stride(from: 0, to: height, by: 2) {
                        for i in stride(from: 0, to: width, by: 2) {
                            var sumU: Float = 0
                            var sumV: Float = 0
                            for y in 0..<2 {
                                let row = min(j + y, height - 1)
                                let rowPtr = base.advanced(by: row * bytesPerRow).assumingMemoryBound(to: UInt8.self)
                                for x in 0..<2 {
                                    let col = min(i + x, width - 1)
                                    let pixel = rowPtr.advanced(by: col * 4)
                                    let b = Float(pixel[0])
                                    let g = Float(pixel[1])
                                    let r = Float(pixel[2])
                                    let cb = (-0.168736 * r - 0.331264 * g + 0.5 * b) + 128.0
                                    let cr = (0.5 * r - 0.418688 * g - 0.081312 * b) + 128.0
                                    sumU += cb
                                    sumV += cr
                                }
                            }
                            var uVal = sumU / 4.0
                            var vVal = sumV / 4.0
                            if uVal < 0 { uVal = 0 } ; if uVal > 255 { uVal = 255 }
                            if vVal < 0 { vVal = 0 } ; if vVal > 255 { vVal = 255 }
                            uOut[uIndex] = UInt8(uVal)
                            vOut[vIndex] = UInt8(vVal)
                            uIndex += 1
                            vIndex += 1
                        }
                    }
                }
            }
        }

        var i420 = Data(capacity: yPlaneSize + uPlaneSize + vPlaneSize)
        i420.append(yData)
        i420.append(uData)
        i420.append(vData)
        return i420
    }
}

private enum createBGRA {
    static func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb)
        if status != kCVReturnSuccess {
            return nil
        }
        return pb
    }
}


