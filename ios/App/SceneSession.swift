import AVFoundation
import Combine
import UIKit

enum SampleScene: Int, CaseIterable, Identifiable {
    case camera = 0, trtc, agora, zego
    var id: Int { rawValue }
    var name: String { ["相机美颜", "腾讯云 TRTC", "声网 Agora", "即构 ZEGO"][rawValue] }
    var detail: String { ["本地预览 · 参数调节 · 原图对比", "美颜视频通话 · 双端画面", "自定义视频 · 美颜通话", "自定义采集 · 美颜推拉流"][rawValue] }
}

struct RoomFields {
    var appID = ""
    var room = "1001"
    var user = ""
    var token = ""
    var microphone = false
    static func saved(for scene: SampleScene, microphone: Bool) -> RoomFields {
        let defaults = UserDefaults.standard
        let prefix = "scene.\(scene.rawValue)."
        return RoomFields(appID: defaults.string(forKey: prefix + "appID") ?? "",
            room: defaults.string(forKey: prefix + "room") ?? "1001",
            user: defaults.string(forKey: prefix + "user") ?? (scene == .agora ? String(UInt32.random(in: 1...2_147_483_647)) : "user_" + UUID().uuidString.prefix(6)),
            token: "", microphone: microphone)
    }
    func save(for scene: SampleScene) {
        let defaults = UserDefaults.standard; let prefix = "scene.\(scene.rawValue)."
        defaults.set(appID, forKey: prefix + "appID"); defaults.set(room, forKey: prefix + "room"); defaults.set(user, forKey: prefix + "user")
    }

    func validated(for scene: SampleScene) throws -> RoomFields {
        var fields = self
        fields.appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        fields.room = room.trimmingCharacters(in: .whitespacesAndNewlines)
        fields.user = user.trimmingCharacters(in: .whitespacesAndNewlines)
        fields.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw NSError(domain: "ai.snapbeauty.samples.config", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        func matches(_ value: String, _ pattern: String) -> Bool { value.range(of: pattern, options: .regularExpression) != nil }
        try require(!fields.token.isEmpty, scene == .trtc ? "请填写有效 UserSig。" : "请填写有效 Token。")
        if scene == .agora {
            try require(matches(fields.appID, "^[0-9a-fA-F]{32}$"), "App ID 应为 32 位十六进制字符。")
            try require((UInt64(fields.user) ?? 0) > 0 && (UInt64(fields.user) ?? .max) <= 2_147_483_647, "UID 应为 1–2147483647。")
        } else {
            let limit: UInt64 = scene == .trtc ? 2_147_483_647 : 4_294_967_295
            try require((UInt64(fields.appID) ?? 0) > 0 && (UInt64(fields.appID) ?? .max) <= limit, "AppID 不是有效正整数。")
            try require(matches(fields.user, "^[A-Za-z0-9_-]{1,32}$"), "用户 ID 需为 1–32 位字母、数字、下划线或短横线。")
        }
        if scene == .trtc {
            try require((UInt64(fields.room) ?? 0) > 0 && (UInt64(fields.room) ?? .max) <= 2_147_483_647, "房间号应为 1–2147483647。")
        } else { try require(matches(fields.room, "^[A-Za-z0-9_-]{1,64}$"), "房间或频道名称需为 1–64 位字母、数字、下划线或短横线。") }
        return fields
    }
}

final class SceneSession: ObservableObject {
    @Published var status = "正在准备相机…"
    @Published var roomStatus = "仅本地预览，尚未加入房间"
    @Published var joining = false
    @Published var joined = false
    @Published var cameraDenied = false
    @Published var cameraUnavailable = false
    @Published var effectUnavailable = false
    @Published var running = false
    @Published var microphoneEnabled = false
    let scene: SampleScene
    let remoteView = UIView()
    var preview: ((CVPixelBuffer, Bool) -> Void)?
    private let pipeline = BeautyPipeline()
    private let lock = NSLock()
    private var capture: CameraCapture?
    private var transport: SampleRTCSession?
    private var active = false
    private var frameGeneration = 0
    private var permissionGeneration = 0
    private var roomGeneration = 0
    private var lastStatusTime = 0.0

    init(scene: SampleScene) { self.scene = scene; remoteView.backgroundColor = UIColor(white: 0.1, alpha: 1) }
    func update(_ snapshot: EffectSnapshot) { pipeline.update(snapshot) }
    func setMicrophone(_ enabled: Bool) {
        guard !joining else { return }
        if enabled && AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
            let generation = permissionGeneration
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] allowed in DispatchQueue.main.async {
                guard let self, self.permissionGeneration == generation else { return }
                if allowed { self.setMicrophone(true) } else { self.microphoneEnabled = false; self.roomStatus = "麦克风权限未开启，可关闭麦克风后加入。" }
            } }
            return
        }
        do { try transport?.setMicrophone(enabled); microphoneEnabled = enabled }
        catch { roomStatus = error.localizedDescription }
    }
    func start() {
        guard !lock.locked({ active }) else { return }
        permissionGeneration += 1; let generation = permissionGeneration
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: startCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in DispatchQueue.main.async {
                guard let self, self.permissionGeneration == generation else { return }
                if allowed { self.startCamera() } else { self.cameraDenied = true; self.status = "请允许相机权限。" }
            } }
        default: cameraDenied = true; status = "请在系统设置中允许相机权限。"
        }
    }
    private func startCamera() {
        cameraDenied = false; cameraUnavailable = false
        guard !lock.locked({ active }) else { return }
        let frameToken = lock.locked { () -> Int in active = true; frameGeneration += 1; return frameGeneration }; running = true
        let camera = CameraCapture(); capture = camera
        camera.frame = { [weak self] input, timestamp, front in
            guard let self, self.lock.locked({ self.active && self.frameGeneration == frameToken }) else { return }
            let (output, message) = self.pipeline.process(input)
            let effectUnavailable = self.pipeline.isBypassed
            let sender = self.lock.locked { self.active && self.frameGeneration == frameToken ? self.transport : nil }
            sender?.send(output, timestamp: timestamp)
            let now = ProcessInfo.processInfo.systemUptime
            let updateStatus = now - self.lastStatusTime > 0.5
            if updateStatus { self.lastStatusTime = now }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.lock.locked({ self.active && self.frameGeneration == frameToken }) else { return }
                self.preview?(output, front)
                if self.effectUnavailable != effectUnavailable { self.effectUnavailable = effectUnavailable }
                if updateStatus { self.status = message }
            }
        }
        camera.failure = { [weak self] message in DispatchQueue.main.async {
            guard let self, self.lock.locked({ self.frameGeneration == frameToken }) else { return }
            self.lock.locked { self.active = false }; self.status = message; self.running = false; self.cameraUnavailable = true
        } }
        camera.start()
    }
    func flip() { pipeline.resetTracking(); capture?.flip() }
    func retryEffects() { pipeline.resetTracking(); effectUnavailable = false }
    func join(_ raw: RoomFields) {
        guard scene != .camera, !joining, !joined else { return }
        do {
            let fields = try raw.validated(for: scene)
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
                start(); roomStatus = "允许相机权限后再加入。"; return
            }
            if fields.microphone && AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
                let generation = permissionGeneration
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] allowed in DispatchQueue.main.async {
                    guard let self, self.permissionGeneration == generation else { return }
                    if allowed { self.join(fields) } else { self.roomStatus = "麦克风权限未开启，可关闭麦克风后加入。" }
                } }
                return
            }
            start(); joining = true
            roomGeneration += 1; let roomToken = roomGeneration
            let adapter = SampleRTCSession(vendor: scene.rawValue, remoteView: remoteView) { [weak self] message, state in
                guard let self, self.roomGeneration == roomToken else { return }
                self.roomStatus = message; self.joining = state == 1; self.joined = state == 2
            }
            lock.locked { transport = adapter }
            try adapter.join(appID: fields.appID, room: fields.room, user: fields.user, token: fields.token, microphone: fields.microphone)
        } catch { joining = false; roomStatus = error.localizedDescription }
    }
    func leave() {
        roomGeneration += 1
        let adapter = lock.locked { () -> SampleRTCSession? in let value = transport; transport = nil; return value }
        adapter?.stop(); joining = false; joined = false; roomStatus = "仅本地预览，尚未加入房间"
    }
    func stop() {
        permissionGeneration += 1
        leave()
        let stopToken = lock.locked { () -> Int in active = false; frameGeneration += 1; return frameGeneration }
        let camera = capture; capture = nil; running = false
        camera?.stop { [weak self, pipeline] in
            guard let self else { pipeline.release(); return }
            self.lock.locked {
                // A previous capture's delayed teardown must not release a new session's processor.
                if !self.active && self.frameGeneration == stopToken { pipeline.release() }
            }
        }
        status = "已停止，可重新开启预览"
    }
}
