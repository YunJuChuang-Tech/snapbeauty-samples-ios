import SwiftUI

struct SceneView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var effects = EffectsStore()
    @StateObject private var session: SceneSession
    @State private var roomPresented = false
    @State private var morePresented = false
    @State private var visible = false
    init(scene: SampleScene) { _session = StateObject(wrappedValue: SceneSession(scene: scene)) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { dismiss() } label: { Text("‹").font(.system(size: 30)).frame(width: 28, height: 44) }
                    .accessibilityLabel("返回场景列表").accessibilityIdentifier("scene-back")
                SampleMark().stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: 32, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("SNAPBEAUTY").font(.system(size: 14, weight: .bold)).tracking(1.5)
                    Text("SAMPLES  /  \(session.scene.name)").font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%02d", session.scene.rawValue + 1)).font(.system(size: 12, design: .monospaced)).foregroundColor(accent)
            }.padding(.horizontal, 16).padding(.vertical, 8).background(ink)
            ZStack(alignment: .bottom) {
                VideoPreview(session: session)
                VStack {
                    HStack(alignment: .top) {
                        Text("●  LIVE PREVIEW").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundColor(accent)
                            .padding(12).background(ink.opacity(0.7)).cornerRadius(18)
                        Spacer()
                        Button { session.flip() } label: {
                            VStack(spacing: 4) { ActionGlyph(kind: .flip).stroke(accent, lineWidth: 1.7).frame(width: 26, height: 26); Text("翻转").font(.system(size: 10)) }
                                .frame(width: 62, height: 64).background(ink.opacity(0.7)).cornerRadius(22)
                        }.accessibilityLabel("切换前后摄像头").disabled(!session.running)
                    }
                    HStack { Spacer(); if session.joined { RemotePreview(view: session.remoteView).frame(width: 108, height: 144).cornerRadius(16) } }
                    Spacer()
                }.padding(16)
                if session.cameraDenied || session.cameraUnavailable {
                    VStack(spacing: 14) {
                        Text(session.cameraDenied ? "让美好进入画面" : "暂时无法预览").font(.title2.bold())
                        Text(session.status).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button(session.cameraDenied ? "开启相机权限" : "重试") {
                            if session.cameraDenied { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                            else { session.start() }
                        }.padding(.horizontal, 24).padding(.vertical, 12).background(accent).foregroundColor(ink).cornerRadius(24)
                    }.padding(28).background(ink.opacity(0.94)).cornerRadius(24).padding(.bottom, session.scene == .trtc ? 270 : 370)
                }
                VStack(spacing: 0) {
                    HStack {
                        Text(session.status).font(.system(size: 12))
                        if session.effectUnavailable {
                            Button("重试美颜") { session.retryEffects() }.font(.system(size: 12, weight: .semibold))
                                .foregroundColor(accent).accessibilityIdentifier("retry-effects")
                        }
                    }.padding(.horizontal, 14).padding(.vertical, 9)
                        .background(ink.opacity(0.75)).cornerRadius(18).padding(.bottom, 18)
                    if session.scene == .trtc { trtcControls }
                    else {
                        if session.scene != .camera { roomControls }
                        EffectsPanel(effects: effects)
                    }
                }
            }.clipped()
        }.background(ink).navigationBarHidden(true).buttonStyle(SceneButtonStyle())
            .accessibilityHidden(roomPresented || morePresented)
            .onReceive(effects.$snapshot) { session.update($0) }
            .onAppear { visible = true; session.update(effects.snapshot); session.start() }
            .onDisappear { visible = false; effects.snapshot.original = false; session.stop() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in effects.snapshot.original = false; session.stop() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in if visible { session.start() } }
            .sheet(isPresented: $roomPresented) { RoomForm(scene: session.scene, microphone: session.microphoneEnabled) { fields in session.join(fields) } }
            .sheet(isPresented: $morePresented, onDismiss: { effects.snapshot.original = false }) {
                NavigationView {
                    VStack { EffectControls(effects: effects); Spacer() }.padding(20).background(panel)
                        .navigationTitle("美肤 · 美型 · 妆容 · 滤镜").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { morePresented = false } } }
                }
            }
    }
    private var mic: some View {
        Toggle("麦克风", isOn: Binding(get: { session.microphoneEnabled }, set: { session.setMicrophone($0) }))
            .font(.system(size: 12)).fixedSize().disabled(session.joining).accessibilityIdentifier("microphone")
    }
    private var roomControls: some View {
        VStack(spacing: 7) {
            HStack { Text(session.roomStatus).font(.system(size: 11)); Spacer(minLength: 8); mic }
            HStack(spacing: 8) {
                sceneButton(session.scene == .agora ? "加入频道" : "加入房间", highlighted: true) { roomPresented = true }
                    .disabled(session.joined || session.joining).accessibilityIdentifier("join-room")
                sceneButton(session.scene == .agora ? "退出频道" : "退出房间") { session.leave() }
                    .disabled(!session.joined && !session.joining).accessibilityIdentifier("leave-room")
            }
            Text("只在加入后发送画面 · 切到后台自动退出").font(.system(size: 10)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.horizontal, 20).padding(.vertical, 10).background(ink)
    }
    private var trtcControls: some View {
        VStack(spacing: 10) {
            Text(session.roomStatus).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                sceneButton("仅预览") { session.start() }.disabled(session.running || session.joining || session.joined).accessibilityIdentifier("start-preview")
                sceneButton("加入房间", highlighted: true) { roomPresented = true }.disabled(session.joining || session.joined).accessibilityIdentifier("join-room")
                sceneButton("停止") { effects.snapshot.original = false; session.stop() }.disabled(!session.running && !session.joining && !session.joined).accessibilityIdentifier("stop-preview")
            }
            HStack(spacing: 10) {
                Text("磨皮").font(.system(size: 13))
                Slider(value: Binding(get: { Double(effects.snapshot.values[0]) }, set: { effects.snapshot.values[0] = Float($0) }), in: 0...1, step: 0.01).accessibilityLabel("磨皮强度")
                Button("更多效果") { morePresented = true }.font(.system(size: 12)).padding(12).background(ink).cornerRadius(18).accessibilityIdentifier("more-effects")
            }
            HStack { mic; Spacer(); CompareControl(effects: effects, identifier: "trtc-compare-original").frame(width: 172, height: 48) }
            Text("麦克风默认关闭 · 切到后台自动退出房间").font(.system(size: 10)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.horizontal, 20).padding(.vertical, 14).background(panel).cornerRadius(24)
    }
    private func sceneButton(_ title: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 12)).frame(maxWidth: .infinity).frame(height: 44)
            .foregroundColor(highlighted ? ink : .white).background(highlighted ? accent : Color(red: 0.19, green: 0.23, blue: 0.19)).cornerRadius(18) }
    }
}

private struct SceneButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
    }
}

struct EffectsPanel: View {
    @ObservedObject var effects: EffectsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var collapsed = false
    @State private var drag: CGFloat = 0
    @State private var dragging = false
    @State private var top: CGFloat = 0
    private let contentHeight: CGFloat = 274
    private var revealed: CGFloat { max(0, min(contentHeight, (collapsed ? 0 : contentHeight) - drag)) }
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 5) {
                Capsule().fill(Color(red: 0.40, green: 0.45, blue: 0.40)).frame(width: 30, height: 3)
                Text(collapsed ? "展开效果面板  ↑" : "收起面板  ↓").font(.system(size: 11)).foregroundColor(accent)
            }.frame(maxWidth: .infinity).frame(height: 48).contentShape(Rectangle())
                .onTapGesture { settle(!collapsed) }.accessibilityAddTraits(.isButton).accessibilityAction { settle(!collapsed) }
                .accessibilityLabel("效果面板").accessibilityValue(collapsed ? "已收起" : "已展开").accessibilityIdentifier("effect-panel-handle")
            EffectControls(effects: effects).padding(.bottom, 12).frame(height: contentHeight, alignment: .top)
                .frame(height: revealed, alignment: .top).clipped().accessibilityHidden(collapsed && !dragging)
        }.padding(.horizontal, 20)
            .background(GeometryReader { geometry in Color.clear.preference(key: PanelTop.self, value: geometry.frame(in: .global).minY) })
            .onPreferenceChange(PanelTop.self) { top = $0 }
            .background(panel).cornerRadius(24)
            .simultaneousGesture(DragGesture(minimumDistance: 10, coordinateSpace: .global).onChanged { value in
                // Horizontal option swipes and slider gestures retain their own interaction.
                let dy = value.translation.height, dx = value.translation.width
                guard dragging || abs(dy) > abs(dx) else { return }
                let localStartY = value.startLocation.y - top
                guard dragging || collapsed || !(180...220).contains(localStartY) else { return }
                if !dragging {
                    guard (collapsed && dy < 0) || (!collapsed && dy > 0) else { return }
                    dragging = true; effects.snapshot.original = false
                }
                drag = dy
            }.onEnded { value in
                guard dragging else { return }
                let predicted = (collapsed ? 0 : contentHeight) - value.predictedEndTranslation.height
                settle(predicted < contentHeight / 2)
            })
    }
    private func settle(_ value: Bool) {
        effects.snapshot.original = false
        withAnimation(reduceMotion ? nil : .timingCurve(0.2, 0, 0, 1, duration: 0.26)) { collapsed = value; drag = 0; dragging = false }
    }
}

private struct PanelTop: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct EffectControls: View {
    @ObservedObject var effects: EffectsStore
    @State private var settingsPresented = false
    private var selectedID: String {
        effects.category < 2 ? "parameter-\(effects.selectedIndex)" : effects.category == 2 ? "style-\(effects.snapshot.style)" : "filter-\(effects.snapshot.filter)"
    }
    private var hint: String {
        if effects.category == 2 {
            if let error = effects.resourceError { return error }
            if effects.snapshot.style.isEmpty { return "选择一套妆容后可调浓度" }
            if effects.snapshot.filterFollowsMakeup {
                let name = effects.filters.first { $0.key == effects.snapshot.filter }?.name ?? "滤镜"
                return "已搭配 \(name) · 浓度联动"
            }
        }
        if effects.category == 3 && effects.snapshot.filterFollowsMakeup { return "随妆容浓度联动 · 手动调节后独立" }
        if effects.category == 3 && effects.snapshot.filter.isEmpty { return "选择滤镜后可调强度" }
        return effects.currentParameter?.neutral == 0.5 ? "左右滑动选项 · 0 为原始比例 · 已调 \(effects.adjustedCount) 项" : "左右滑动选项 · 描边为已调整 · 已调 \(effects.adjustedCount) 项"
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(["美肤", "美型", "妆容", "滤镜"].enumerated()), id: \.offset) { index, name in
                    Button { effects.category = index } label: {
                        Text(name).font(.system(size: 15, weight: effects.category == index ? .bold : .regular))
                            .foregroundColor(effects.category == index ? accent : .secondary).frame(maxWidth: .infinity).frame(height: 44)
                    }.accessibilityIdentifier("effect-category-\(index)").accessibilityAddTraits(effects.category == index ? .isSelected : [])
                }
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if effects.category < 2 {
                            ForEach(effects.category == 0 ? Effects.skin : Effects.shape) { item in
                                choice(item.name, id: "parameter-\(item.index)", selected: effects.selectedIndex == item.index, adjusted: effects.adjusted(item.index)) {
                                    if effects.category == 0 { effects.selectedSkin = item.index } else { effects.selectedShape = item.index }
                                }
                            }
                        } else {
                            ForEach(effects.category == 2 ? Effects.styles : effects.filters) { item in
                                choice(item.name, id: (effects.category == 2 ? "style-" : "filter-") + item.key,
                                       selected: (effects.category == 2 ? effects.snapshot.style : effects.snapshot.filter) == item.key) {
                                    if effects.category == 2 { effects.snapshot.selectStyle(item.key) } else { effects.snapshot.selectFilter(item.key) }
                                }
                            }
                        }
                    }.padding(.horizontal, 3).frame(height: 48)
                }.accessibilityIdentifier("effect-options")
                    .onChange(of: selectedID) { id in withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) } }
                    .onAppear { proxy.scrollTo(selectedID, anchor: .center) }
            }.frame(height: 48)
            HStack {
                Text(effects.currentTitle).font(.system(size: 12)).accessibilityIdentifier("effect-current-name")
                Spacer()
                Button("恢复默认") { effects.restoreCurrent() }.font(.system(size: 11)).foregroundColor(.secondary)
                    .opacity(effects.category < 2 && effects.adjusted(effects.selectedIndex) ? 1 : 0)
                    .disabled(effects.category >= 2 || !effects.adjusted(effects.selectedIndex))
                    .accessibilityLabel("\(effects.currentTitle)恢复默认").accessibilityIdentifier("restore-current")
                Text(effects.displayValue()).font(.system(size: 13, design: .monospaced)).foregroundColor(accent).frame(width: 36, alignment: .trailing).accessibilityIdentifier("effect-amount")
            }.frame(height: 40)
            Slider(value: Binding(get: { Double(effects.snapshot.values[effects.selectedIndex]) }, set: { effects.snapshot.setAmount(effects.selectedIndex, Float($0)) }), in: 0...1, step: 0.01)
                .accessibilityLabel("\(effects.currentTitle)强度").accessibilityIdentifier("effect-slider").disabled(!effects.amountEnabled).frame(height: 40)
            HStack(spacing: 6) {
                Text(hint).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                Button("人脸设置") { settingsPresented = true }.font(.system(size: 10)).foregroundColor(accent).frame(width: 82, height: 32)
                    .background(Color(red: 0.17, green: 0.20, blue: 0.18)).cornerRadius(16).accessibilityIdentifier("face-settings")
            }.frame(height: 38)
            HStack(spacing: 16) {
                Button { effects.reset() } label: {
                    VStack(spacing: 3) { ActionGlyph(kind: .reset).stroke(accent, lineWidth: 1.7).frame(width: 26, height: 26); Text("重置").font(.system(size: 10)) }.frame(width: 72, height: 52)
                }.accessibilityLabel("重置全部效果").accessibilityIdentifier("reset-effects")
                CompareControl(effects: effects).frame(maxWidth: .infinity).frame(height: 48)
            }.frame(height: 52)
        }.sheet(isPresented: $settingsPresented) { FaceSettings(effects: effects) }
    }
    private func choice(_ name: String, id: String, selected: Bool, adjusted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name).font(.system(size: 12)).lineLimit(1).fixedSize().padding(.horizontal, 14).frame(minWidth: 56).frame(height: 36)
                .foregroundColor(selected ? ink : .white).background(selected ? accent : Color(red: 0.17, green: 0.20, blue: 0.18)).cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(adjusted && !selected ? accent : .clear, lineWidth: 1))
        }.id(id).accessibilityIdentifier(id).accessibilityLabel(adjusted ? "\(name)，已调整" : name)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct CompareControl: View {
    @ObservedObject var effects: EffectsStore
    var identifier = "compare-original"
    var body: some View {
        Text(effects.snapshot.original ? "正在查看原图" : "按住对比原图").font(.system(size: 14, weight: .bold))
            .foregroundColor(ink).frame(maxWidth: .infinity, maxHeight: .infinity).background(accent).cornerRadius(26).contentShape(Rectangle())
            // Set the flag on touch down / up directly; onChange of a GestureState is not delivered reliably.
            .highPriorityGesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !effects.snapshot.original { effects.snapshot.original = true } }
                .onEnded { _ in effects.snapshot.original = false })
            .onDisappear { effects.snapshot.original = false }
            .accessibilityAddTraits(.isButton).accessibilityLabel("按住查看原图，松开恢复效果").accessibilityIdentifier(identifier)
            .accessibilityValue(effects.snapshot.original ? "原图" : "效果")
            .accessibilityAction { effects.snapshot.original.toggle() }
    }
}

struct FaceSettings: View {
    @ObservedObject var effects: EffectsStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            Form {
                Text("当前版本支持单人美颜。多人脸和处理预算暂不可调节。")
                    .accessibilityIdentifier("single-face-support")
            }.navigationTitle("人脸设置").navigationBarTitleDisplayMode(.inline).toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }
}

struct ActionGlyph: Shape {
    enum Kind { case flip, reset }
    let kind: Kind
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if kind == .flip {
            path.addRoundedRect(in: CGRect(x: 6, y: 9, width: 20, height: 15), cornerSize: CGSize(width: 3, height: 3))
            path.addEllipse(in: CGRect(x: 12.5, y: 12.5, width: 7, height: 7))
            path.move(to: CGPoint(x: 9, y: 5)); path.addLine(to: CGPoint(x: 23, y: 5)); path.addLine(to: CGPoint(x: 20, y: 2))
            path.move(to: CGPoint(x: 23, y: 28)); path.addLine(to: CGPoint(x: 9, y: 28)); path.addLine(to: CGPoint(x: 12, y: 31))
        } else {
            path.addArc(center: CGPoint(x: 16, y: 16), radius: 9, startAngle: .degrees(-60), endAngle: .degrees(230), clockwise: false)
            path.move(to: CGPoint(x: 6, y: 7)); path.addLine(to: CGPoint(x: 7, y: 14)); path.addLine(to: CGPoint(x: 13, y: 11))
        }
        // Normalize our own 32-unit geometric icon to the requested bounds.
        return path.applying(CGAffineTransform(scaleX: rect.width / 32, y: rect.height / 32))
    }
}
