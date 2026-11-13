import SnapBeautyResources
import AVFoundation
import CoreImage
import MetalKit
import SwiftUI

final class BeautyPipeline {
    typealias FrameOperation = (CVPixelBuffer, EffectSnapshot) throws -> (CVPixelBuffer, String)
    private let lock = NSLock()
    private let settingsLock = NSLock()
    private var settings = EffectSnapshot()
    private var processor: BeautyFrameProcessor?
    private let assets: URL
    private let shaders: URL
    private let operation: FrameOperation?
    private var failureMessage: String?
    var isBypassed: Bool { lock.locked { failureMessage != nil } }
    init(bundle: Bundle = .main, operation: FrameOperation? = nil) {
        assets = (try? SampleSPMResources.assets.get()) ?? bundle.bundleURL.appendingPathComponent("Assets")
        shaders = SnapBeautyResources.shaders
        self.operation = operation
    }
    func update(_ snapshot: EffectSnapshot) { settingsLock.locked { settings = snapshot } }
    func process(_ input: CVPixelBuffer) -> (CVPixelBuffer, String) {
        lock.locked {
            let snapshot = settingsLock.locked { settings }
            if let failureMessage { return (input, failureMessage) }
            if snapshot.original { return (input, "正在查看原图") }
            do {
                if let operation { return try operation(input, snapshot) }
                if processor == nil { processor = try BeautyFrameProcessor(assets: assets.path, shaders: shaders.path) }
                guard let processor else { throw CocoaError(.coderInvalidValue) }
                let style = snapshot.values[36] > 0 && !snapshot.style.isEmpty ? snapshot.style : nil
                let output = try processor.process(input, values: snapshot.sdkValues, style: style,
                    filter: snapshot.filter.isEmpty ? nil : snapshot.filter, maxFaces: 1)
                return (output, "已识别 \(processor.faceCount) 人脸 · \(Int(processor.costMilliseconds)) ms")
            } catch {
                processor = nil
                let error = error as NSError
                let message = "美颜处理失败，已显示原图，请重试"
                NSLog("%@; %@/%ld: %@", message, error.domain, error.code, error.localizedDescription)
                failureMessage = message
                return (input, message)
            }
        }
    }
    func resetTracking() { lock.locked { processor = nil; failureMessage = nil } }
    func release() { lock.locked { processor = nil; failureMessage = nil } }
}

final class CameraCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "ai.snapbeauty.samples.camera", qos: .userInitiated)
    private var front = true
    private var running = false
    var frame: ((CVPixelBuffer, CMTime, Bool) -> Void)?
    var failure: ((String) -> Void)?
    func start() { queue.async { [self] in
        guard !running else { return }
        do {
            session.beginConfiguration(); session.sessionPreset = .vga640x480
            try configureInput()
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else { throw CocoaError(.featureUnsupported) }
            session.addOutput(output); orient(output)
            session.commitConfiguration(); session.startRunning(); running = true
        } catch {
            session.inputs.forEach(session.removeInput); session.outputs.forEach(session.removeOutput)
            session.commitConfiguration(); failure?("相机启动失败，请检查权限或重试。")
        }
    } }
    private func configureInput() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back) else { throw CocoaError(.featureUnsupported) }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CocoaError(.featureUnsupported) }
        session.addInput(input)
        try device.lockForConfiguration()
        if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 15 && $0.maxFrameRate >= 15 }) {
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
        }
        device.unlockForConfiguration()
    }
    private func orient(_ output: AVCaptureOutput) {
        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
            if connection.isVideoMirroringSupported { connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = false }
        }
    }
    func flip() { queue.async { [self] in
        guard running else { return }
        session.beginConfiguration()
        let previous = session.inputs
        previous.forEach(session.removeInput); front.toggle()
        do { try configureInput() } catch {
            front.toggle(); previous.forEach { if session.canAddInput($0) { session.addInput($0) } }
            failure?("当前摄像头不可用。")
        }
        session.outputs.forEach(orient); session.commitConfiguration()
    } }
    func stop(completion: @escaping () -> Void) { queue.async { [self] in
        session.stopRunning(); running = false
        session.beginConfiguration(); session.inputs.forEach(session.removeInput); session.outputs.forEach(session.removeOutput); session.commitConfiguration()
        completion()
    } }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard running, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frame?(buffer, CMSampleBufferGetPresentationTimeStamp(sampleBuffer), front)
    }
}

enum PreviewGeometry {
    static func image(_ frame: CVPixelBuffer, mirror: Bool, size: CGSize) -> CIImage {
        let source = CIImage(cvPixelBuffer: frame)
        let image = mirror ? source.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: source.extent.width, ty: 0)) : source
        let scale = max(size.width / image.extent.width, size.height / image.extent.height)
        let cropped = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)).transformed(by:
            CGAffineTransform(translationX: (size.width - image.extent.width * scale) / 2, y: (size.height - image.extent.height * scale) / 2))
        // CIContext's Metal destination already accounts for presentation coordinates.
        // Texture readback rows are not a screen-space oracle; an extra Y flip inverts the displayed head.
        return cropped
    }
}

final class FrameView: MTKView, MTKViewDelegate {
    private var retainedBuffer: CVPixelBuffer?
    private var mirror = false
    private var context: CIContext!
    private var commands: MTLCommandQueue!
    init() {
        let gpu = MTLCreateSystemDefaultDevice()
        super.init(frame: .zero, device: gpu)
        if let gpu { context = CIContext(mtlDevice: gpu); commands = gpu.makeCommandQueue() }
        framebufferOnly = false; enableSetNeedsDisplay = true; isPaused = true; delegate = self
        colorPixelFormat = .bgra8Unorm; backgroundColor = UIColor(white: 0.06, alpha: 1)
    }
    required init(coder: NSCoder) { fatalError("Programmatic preview") }
    func present(_ frame: CVPixelBuffer, mirror: Bool) {
        retainedBuffer = frame
        self.mirror = mirror
        setNeedsDisplay()
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { setNeedsDisplay() }
    func draw(in view: MTKView) {
        guard let retainedBuffer, let drawable = currentDrawable, let command = commands?.makeCommandBuffer(), context != nil else { return }
        let size = drawableSize
        let adjusted = PreviewGeometry.image(retainedBuffer, mirror: mirror, size: size)
        context.render(adjusted, to: drawable.texture, commandBuffer: command, bounds: CGRect(origin: .zero, size: size), colorSpace: CGColorSpaceCreateDeviceRGB())
        command.addCompletedHandler { _ in _ = retainedBuffer }
        command.present(drawable); command.commit()
    }
}

struct VideoPreview: UIViewRepresentable {
    let session: SceneSession
    func makeUIView(context: Context) -> FrameView {
        let view = FrameView()
        session.preview = { [weak view] frame, mirrored in view?.present(frame, mirror: mirrored) }
        return view
    }
    func updateUIView(_ uiView: FrameView, context: Context) {}
}

struct RemotePreview: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

#if DEBUG && targetEnvironment(simulator)
/// Simulator-only fixture exercises the real MTKView/CAMetalLayer, not a readback texture.
struct OrientationPreviewFixture: UIViewRepresentable {
    func makeUIView(context: Context) -> FrameView {
        let view = FrameView()
        var allocated: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 48, 64, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &allocated)
        if let frame = allocated {
            CVPixelBufferLockBaseAddress(frame, [])
            let bytes = CVPixelBufferGetBaseAddress(frame)!.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(frame)
            for y in 0..<64 { for x in 0..<48 {
                let offset = y * stride + x * 4
                bytes[offset] = y < 32 ? 20 : 220
                bytes[offset + 1] = x < 24 ? 180 : 40
                bytes[offset + 2] = y < 32 ? 220 : 20
                bytes[offset + 3] = 255
            } }
            CVPixelBufferUnlockBaseAddress(frame, [])
            DispatchQueue.main.async { view.present(frame, mirror: ProcessInfo.processInfo.environment["SAMPLE_PREVIEW_MIRROR"] == "1") }
        }
        return view
    }
    func updateUIView(_ uiView: FrameView, context: Context) {}
}
#endif

// The SDK bundle is read-only. Merge the example's own makeup alongside a copy of its assets.
enum SampleSPMResources {
    static let assets: Result<URL, Error> = Result {
        let fm = FileManager.default
        let target = fm.temporaryDirectory.appendingPathComponent("snapbeauty-sample-" + UUID().uuidString, isDirectory: true)
        try fm.copyItem(at: SnapBeautyResources.assets, to: target)
        for folder in ["makeup", "sample_makeup"] {
            let source = Bundle.main.bundleURL.appendingPathComponent("Assets/" + folder, isDirectory: true)
            try fm.copyItem(at: source, to: target.appendingPathComponent(folder, isDirectory: true))
        }
        return target
    }
}
