import Foundation
import VideoToolbox
import AVFoundation

protocol H264EncoderDelegate: AnyObject {
    func h264Encoder(_ encoder: H264Encoder, didEncodeNALU data: Data, isKeyFrame: Bool)
}

class H264Encoder {
    weak var delegate: H264EncoderDelegate?

    private var session: VTCompressionSession?
    private let width: Int
    private let height: Int

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        setupEncoder()
    }

    private func setupEncoder() {
        let status = VTCompressionSessionCreate(
            allocator: nil,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: compressionCallback,
            refcon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            NSLog("❌ Failed to create compression session, status=\(status)")
            return
        }

        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)

        VTCompressionSessionPrepareToEncodeFrames(session)
    }

    func encode(pixelBuffer: CVPixelBuffer, pts: CMTime) {
        guard let session = session else { return }
        var flags: VTEncodeInfoFlags = []
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )

        if status != noErr {
            NSLog("❌ Encode error: \(status)")
        }
    }

    func finish() {
        guard let session = session else { return }
        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
        VTCompressionSessionInvalidate(session)
        self.session = nil
    }
}

private func compressionCallback(
    outputCallbackRefCon: UnsafeMutableRawPointer?,
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTEncodeInfoFlags,
    sampleBuffer: CMSampleBuffer?
) {
    guard
        status == noErr,
        let sampleBuffer = sampleBuffer,
        CMSampleBufferDataIsReady(sampleBuffer),
        let refCon = outputCallbackRefCon
    else { return }

    let encoder: H264Encoder = Unmanaged.fromOpaque(refCon).takeUnretainedValue()

    // Check if keyframe
    let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true)
    var isKeyFrame = false
    if let dict = (attachments as? [CFDictionary])?.first {
        let dependsOnOthers = CFDictionaryContainsKey(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DependsOnOthers).toOpaque())
        isKeyFrame = !dependsOnOthers
    }

    // Extract NAL units
    guard let desc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
    var dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)

    var length: Int = 0
    var totalLength: Int = 0
    var dataPointer: UnsafeMutablePointer<Int8>?

    let statusCode = CMBlockBufferGetDataPointer(dataBuffer!, atOffset: 0, lengthAtOffsetOut: &length, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
    if statusCode != noErr {
        NSLog("❌ CMBlockBufferGetDataPointer error: \(statusCode)")
        return
    }

    var bufferOffset = 0
    let AVCCHeaderLength = 4

    while bufferOffset < totalLength {
        // Read NAL length
        var nalUnitLength: UInt32 = 0
        memcpy(&nalUnitLength, dataPointer! + bufferOffset, AVCCHeaderLength)
        nalUnitLength = CFSwapInt32BigToHost(nalUnitLength)

        // NAL data
        let nalStart = dataPointer! + bufferOffset + AVCCHeaderLength
        let nalData = Data(bytes: nalStart, count: Int(nalUnitLength))

        // Prefix with Annex-B start code
        var annexB = Data([0x00, 0x00, 0x00, 0x01])
        annexB.append(nalData)

        encoder.delegate?.h264Encoder(encoder, didEncodeNALU: annexB, isKeyFrame: isKeyFrame)

        bufferOffset += AVCCHeaderLength + Int(nalUnitLength)
    }

    // SPS/PPS for keyframes
    if isKeyFrame {
        var spsSize: Int = 0
        var spsCount: Int = 0
        var spsPointer: UnsafePointer<UInt8>?
        var ppsSize: Int = 0
        var ppsCount: Int = 0
        var ppsPointer: UnsafePointer<UInt8>?

        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(desc, parameterSetIndex: 0, parameterSetPointerOut: &spsPointer, parameterSetSizeOut: &spsSize, parameterSetCountOut: &spsCount, nalUnitHeaderLengthOut: nil)
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(desc, parameterSetIndex: 1, parameterSetPointerOut: &ppsPointer, parameterSetSizeOut: &ppsSize, parameterSetCountOut: &ppsCount, nalUnitHeaderLengthOut: nil)

        if let spsPointer = spsPointer, spsSize > 0 {
            var spsNAL = Data([0x00, 0x00, 0x00, 0x01])
            spsNAL.append(Data(bytes: spsPointer, count: spsSize))
            encoder.delegate?.h264Encoder(encoder, didEncodeNALU: spsNAL, isKeyFrame: true)
        }

        if let ppsPointer = ppsPointer, ppsSize > 0 {
            var ppsNAL = Data([0x00, 0x00, 0x00, 0x01])
            ppsNAL.append(Data(bytes: ppsPointer, count: ppsSize))
            encoder.delegate?.h264Encoder(encoder, didEncodeNALU: ppsNAL, isKeyFrame: true)
        }
    }
}
