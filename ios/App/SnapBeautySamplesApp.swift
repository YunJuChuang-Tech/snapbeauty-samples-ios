import SwiftUI
import SnapBeauty

let ink = Color(red: 0.063, green: 0.075, blue: 0.067)
let panel = Color(red: 0.10, green: 0.12, blue: 0.105)
let accent = Color(red: 0.867, green: 1, blue: 0.604)

final class LicenseNotice: ObservableObject {
    static let shared = LicenseNotice()
    @Published var show = false
}

@main
struct SnapBeautySamplesApp: App {
    @StateObject private var licenseNotice = LicenseNotice.shared

    init() {
        SnapBeauty.setLicenseErrorHandler { status in
            NSLog("SDK authorization error: %ld; original frames retained", status.code.rawValue)
            DispatchQueue.main.async { LicenseNotice.shared.show = true }
        }
        let path = Bundle.main.bundleURL.appendingPathComponent("Assets/snapbeauty.license")
        let license = (try? String(contentsOf: path, encoding: .utf8)) ?? ""
        _ = SnapBeauty.initialize(license: license)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG && targetEnvironment(simulator)
                if ProcessInfo.processInfo.environment["SAMPLE_PREVIEW_CHART"] == "1" { OrientationPreviewFixture() }
                else { HomeView() }
                #else
                HomeView()
                #endif
            }.preferredColorScheme(.dark).tint(accent)
                .alert("美颜授权不可用", isPresented: $licenseNotice.show) {
                    Button("知道了", role: .cancel) { }
                } message: {
                    Text("当前显示原图，请检查应用授权配置。")
                }
        }
    }
}

struct SampleMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.width * 0.15, y: rect.height * 0.15, width: rect.width * 0.6, height: rect.height * 0.74))
        path.move(to: CGPoint(x: rect.width * 0.31, y: rect.height * 0.65))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.60, y: rect.height * 0.65), control: CGPoint(x: rect.width * 0.45, y: rect.height * 0.81))
        path.move(to: CGPoint(x: rect.width * 0.76, y: 0)); path.addLine(to: CGPoint(x: rect.width * 0.76, y: rect.height * 0.30))
        path.move(to: CGPoint(x: rect.width * 0.61, y: rect.height * 0.15)); path.addLine(to: CGPoint(x: rect.width * 0.91, y: rect.height * 0.15))
        return path
    }
}

struct HomeView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SampleMark().stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 66, height: 66).padding(.bottom, 8)
                    Text("SnapBeauty\nSamples").font(.system(size: 34, weight: .bold))
                    Text("选一个场景，马上开始。").foregroundColor(.secondary).padding(.bottom, 14)
                    ForEach(SampleScene.allCases) { scene in
                        NavigationLink(destination: SceneView(scene: scene)) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(String(format: "%02d  %@", scene.rawValue + 1, scene.name)).font(.headline).foregroundColor(accent)
                                Text(scene.detail).font(.subheadline).foregroundColor(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(22).background(panel).cornerRadius(22)
                        }.accessibilityIdentifier("scene-\(scene.rawValue)")
                    }
                    Text("简单一点，自然一点。").font(.footnote).foregroundColor(.secondary).padding(.top, 16)
                }.padding(24)
            }.background(ink).navigationBarHidden(true)
        }.navigationViewStyle(.stack)
    }
}

struct RoomForm: View {
    let scene: SampleScene
    let join: (RoomFields) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var fields = RoomFields()
    @State private var error: String?
    init(scene: SampleScene, microphone: Bool, join: @escaping (RoomFields) -> Void) {
        self.scene = scene; self.join = join
        _fields = State(initialValue: RoomFields.saved(for: scene, microphone: microphone))
    }
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("房间配置")) {
                    TextField(scene == .agora ? "App ID" : "AppID", text: $fields.appID).autocapitalization(.none).disableAutocorrection(true)
                    TextField(scene == .agora ? "频道" : "房间", text: $fields.room).autocapitalization(.none).disableAutocorrection(true)
                    TextField(scene == .agora ? "UID" : "用户 ID", text: $fields.user).autocapitalization(.none).disableAutocorrection(true)
                    SecureField(scene == .trtc ? "UserSig" : "Token", text: $fields.token).textContentType(.oneTimeCode)
                }
                Text("两端使用相同应用和房间、不同用户。会话凭据由服务端生成，默认不开麦克风。").font(.footnote).foregroundColor(.secondary)
                if let error { Text(error).foregroundColor(.orange) }
            }.navigationTitle(scene.name).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { fields.token = ""; dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("加入") {
                        do { let valid = try fields.validated(for: scene); valid.save(for: scene); fields.token = ""; join(valid); dismiss() }
                        catch { self.error = error.localizedDescription }
                    } }
                }
        }
    }
}
