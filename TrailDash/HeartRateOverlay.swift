import AVFoundation
import AVKit
import SwiftUI

/// Floats HR over other apps (onX for navigation) using Picture in Picture, the
/// only way iOS lets an app draw on top of another. The "video" is a frame drawn
/// once a second: the HR number in its zone color. Starts by itself when the
/// rider leaves the app during a ride, or with `start()`.
@Observable
final class HeartRateOverlay: NSObject {
    private(set) var isFloating = false
    /// Shown inline in the app; PiP needs its source layer on screen to start.
    let layer = AVSampleBufferDisplayLayer()

    private let heartRate: HeartRateMonitor
    private var controller: AVPictureInPictureController?
    private var timer: Timer?
    private static let size = CGSize(width: 360, height: 200)

    init(heartRate: HeartRateMonitor) {
        self.heartRate = heartRate
        super.init()
        layer.videoGravity = .resizeAspect
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: layer, playbackDelegate: self)
        let controller = AVPictureInPictureController(contentSource: source)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.requiresLinearPlayback = true
        controller.delegate = self
        self.controller = controller
    }

    /// Start drawing frames (during a ride), so PiP can float when the app goes away.
    func enable() {
        guard timer == nil else { return }
        // PiP needs an active playback session; mix so music and onX voice keep playing.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        render()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.render() }
    }

    func disable() {
        timer?.invalidate()
        timer = nil
        controller?.stopPictureInPicture()
        layer.flushAndRemoveImage()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Float now, without leaving the app first.
    func start() {
        controller?.startPictureInPicture()
    }

    private func render() {
        if layer.status == .failed { layer.flush() }
        guard let buffer = Self.sampleBuffer(bpm: heartRate.bpm) else { return }
        layer.enqueue(buffer)
    }

    /// One frame: the HR number, zone colored, on black.
    private static func sampleBuffer(bpm: Int?) -> CMSampleBuffer? {
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let text = bpm.map(String.init) ?? "--"
            let color = bpm == nil ? UIColor.gray : UIColor(HeartRateZones.color(bpm: bpm))
            let font = UIFont.systemFont(ofSize: 170, weight: .heavy).rounded
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let textSize = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                      withAttributes: attributes)
        }
        guard let cgImage = image.cgImage, let pixels = pixelBuffer(from: cgImage) else { return nil }

        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixels, formatDescriptionOut: &format)
        guard let format else { return nil }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 1),
                                        presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
                                        decodeTimeStamp: .invalid)
        var buffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixels, formatDescription: format,
                                                 sampleTiming: &timing, sampleBufferOut: &buffer)
        guard let buffer else { return nil }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dictionary,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return buffer
    }

    private static func pixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: true,
                          kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                          kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, image.width, image.height, kCVPixelFormatType_32BGRA, attributes, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return buffer
    }
}

extension HeartRateOverlay: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in self.isFloating = true }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in self.isFloating = false }
    }
}

/// A live stream with nothing to seek or pause.
extension HeartRateOverlay: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {}

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
        false
    }

    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController,
                                                didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController,
                                                skipByInterval skipInterval: CMTime) async {}
}

private extension UIFont {
    var rounded: UIFont {
        fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: pointSize) } ?? self
    }
}

/// The overlay's source, shown small in the app. PiP floats this out over other apps.
struct HeartRateOverlayPreview: UIViewRepresentable {
    let overlay: HeartRateOverlay

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.layer.addSublayer(overlay.layer)
        return view
    }

    func updateUIView(_ view: LayerView, context: Context) {}

    final class LayerView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.forEach { $0.frame = bounds }
        }
    }
}
