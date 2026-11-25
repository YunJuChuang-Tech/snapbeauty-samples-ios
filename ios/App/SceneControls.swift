import SwiftUI

struct SceneView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var effects = EffectsStore()
    @StateObject private var session: SceneSession
    @State private var roomPresented = false
    @State private var morePresented = false
    @State private var panelCollapsed = false
    @State private var visible = false
    init(scene: SampleScene) { _session = StateObject(wrappedValue: SceneSession(scene: scene)) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { dismiss() } label: { Text("‹").font(.system(size: 26)).frame(width: 24, height: 34) }
                    .accessibilityLabel("返回场景列表").accessibilityIdentifier("scene-back")
                SampleMark().stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: 24, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SNAPBEAUTY").font(.system(size: 12, weight: .bold)).tracking(1.3)
                    Text("SAMPLES  /  \(session.scene.name)").font(.system(size: 9)).foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%02d", session.scene.rawValue + 1)).font(.system(size: 11, design: .monospaced)).foregroundColor(accent)
            }.padding(.horizontal, 14).padding(.vertical, 5).background(ink)
            ZStack(alignment: .bottom) {
                VideoPreview(session: session)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard session.scene != .trtc else { return }
                        effects.snapshot.original = false
                        withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.24)) { panelCollapsed.toggle() }
                    }
                VStack {
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text(session.status).font(.system(size: 10)).lineLimit(1)
                            if session.effectUnavailable {
                                Button("重试美颜") { session.retryEffects() }.font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(accent).accessibilityIdentifier("retry-effects")
                            }
                        }.padding(.horizontal, 10).padding(.vertical, 6).background(ink.opacity(0.55)).cornerRadius(14)
                        Spacer(minLength: 4)
                        HStack(spacing: 2) {
                            Button { effects.applyGenderPreset(false) } label: {
                                Text("女生").font(.system(size: 11, weight: effects.malePreset ? .regular : .bold))
                                    .foregroundColor(effects.malePreset ? .white : ink)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(effects.malePreset ? Color.clear : accent).cornerRadius(12)
                            }.accessibilityIdentifier("preset-female")
                            Button { effects.applyGenderPreset(true) } label: {
                                Text("男生").font(.system(size: 11, weight: effects.malePreset ? .bold : .regular))
                                    .foregroundColor(effects.malePreset ? ink : .white)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(effects.malePreset ? accent : Color.clear).cornerRadius(12)
                            }.accessibilityIdentifier("preset-male")
                        }.padding(3).background(ink.opacity(0.62)).cornerRadius(15)
                        Button { session.flip() } label: {
                            Text("翻转").font(.system(size: 11)).padding(.horizontal, 11).padding(.vertical, 6)
                                .background(ink.opacity(0.62)).cornerRadius(15)
                        }.accessibilityLabel("切换前后摄像头").disabled(!session.running)
                    }
                    HStack { Spacer(); if session.joined { RemotePreview(view: session.remoteView).frame(width: 108, height: 144).cornerRadius(16) } }
                    Spacer()
                }.padding(.horizontal, 12).padding(.top, 10)
                if session.cameraDenied || session.cameraUnavailable {
                    VStack(spacing: 14) {
                        Text(session.cameraDenied ? "让美好进入画面" : "暂时无法预览").font(.title2.bold())
                        Text(session.status).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button(session.cameraDenied ? "开启相机权限" : "重试") {
                            if session.cameraDenied { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                            else { session.start() }
                        }.padding(.horizontal, 24).padding(.vertical, 12).background(accent).foregroundColor(ink).cornerRadius(24)
                    }.padding(28).background(ink.opacity(0.94)).cornerRadius(24).padding(.bottom, session.scene == .trtc ? 220 : 180)
                }
                VStack(spacing: 0) {
                    if session.scene == .trtc { trtcControls }
                    else {
                        if session.scene != .camera { roomControls }
                        HStack(spacing: 8) {
                            Spacer()
                            Button { effects.reset() } label: {
                                Text("重置").font(.system(size: 11)).foregroundColor(.white)
                                    .padding(.horizontal, 11).frame(height: 28).background(ink.opacity(0.62)).cornerRadius(14)
                            }.accessibilityLabel("重置全部效果").accessibilityIdentifier("reset-effects")
                            CompareControl(effects: effects).frame(width: 98, height: 28)
                        }.padding(.horizontal, 12).padding(.bottom, 6)
                        EffectsPanel(effects: effects, collapsed: $panelCollapsed)
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
    @Binding var collapsed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGFloat = 0
    @State private var dragging = false
    @State private var top: CGFloat = 0
    private let contentHeight: CGFloat = 108
    private var revealed: CGFloat { max(0, min(contentHeight, (collapsed ? 0 : contentHeight) - drag)) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Capsule().fill(Color.white.opacity(0.45)).frame(width: 26, height: 3)
                Text(collapsed ? "展开效果面板  ↑" : "收起面板  ↓").font(.system(size: 10)).foregroundColor(accent)
            }.frame(maxWidth: .infinity).frame(height: 28).contentShape(Rectangle())
                .onTapGesture { settle(!collapsed) }.accessibilityAddTraits(.isButton).accessibilityAction { settle(!collapsed) }
                .accessibilityLabel("效果面板").accessibilityValue(collapsed ? "已收起" : "已展开").accessibilityIdentifier("effect-panel-handle")
            EffectControls(effects: effects).padding(.bottom, 6).frame(height: contentHeight, alignment: .top)
                .frame(height: revealed, alignment: .top).clipped().accessibilityHidden(collapsed && !dragging)
        }.padding(.horizontal, 14)
            .background(GeometryReader { geometry in Color.clear.preference(key: PanelTop.self, value: geometry.frame(in: .global).minY) })
            .onPreferenceChange(PanelTop.self) { top = $0 }
            .background(LinearGradient(colors: [ink.opacity(0.54), ink.opacity(0.76)], startPoint: .top, endPoint: .bottom))
            .cornerRadius(20)
            .simultaneousGesture(DragGesture(minimumDistance: 10, coordinateSpace: .global).onChanged { value in
                // Horizontal option swipes and slider gestures retain their own interaction.
                let dy = value.translation.height, dx = value.translation.width
                guard dragging || abs(dy) > abs(dx) else { return }
                let localStartY = value.startLocation.y - top
                guard dragging || collapsed || !(26...64).contains(localStartY) else { return }
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
        withAnimation(reduceMotion ? nil : .timingCurve(0.2, 0, 0, 1, duration: 0.24)) { collapsed = value; drag = 0; dragging = false }
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
        effects.category < 2 ? "parameter-\(effects.selectedIndex)" : effects.category == 2 ? "style-\(effects.snapshot.style)" : effects.category == 3 ? "filter-\(effects.snapshot.filter)" : "lipstick-\(effects.snapshot.lipstick)"
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(effects.currentTitle).font(.system(size: 11)).lineLimit(1).accessibilityIdentifier("effect-current-name")
                Slider(value: Binding(get: { Double(effects.category == 4 ? effects.snapshot.lipstickAmount : effects.snapshot.values[effects.selectedIndex]) }, set: { if effects.category == 4 { effects.snapshot.lipstickAmounts[effects.snapshot.lipstick] = Float($0) } else { effects.snapshot.setAmount(effects.selectedIndex, Float($0)) } }), in: 0...1, step: 0.01)
                    .accessibilityLabel("\(effects.currentTitle)强度").accessibilityIdentifier("effect-slider").disabled(!effects.amountEnabled)
                Text(effects.displayValue()).font(.system(size: 12, design: .monospaced)).foregroundColor(accent).frame(width: 30, alignment: .trailing).accessibilityIdentifier("effect-amount")
                if effects.category < 2 && effects.adjusted(effects.selectedIndex) {
                    Button("恢复默认") { effects.restoreCurrent() }.font(.system(size: 10)).foregroundColor(.secondary)
                        .accessibilityLabel("\(effects.currentTitle)恢复默认").accessibilityIdentifier("restore-current")
                }
            }.frame(height: 32)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        if effects.category < 2 {
                            ForEach(effects.category == 0 ? Effects.skin : Effects.shape) { item in
                                choice(item.name, id: "parameter-\(item.index)", selected: effects.selectedIndex == item.index, adjusted: effects.adjusted(item.index)) {
                                    if effects.category == 0 { effects.selectedSkin = item.index } else { effects.selectedShape = item.index }
                                }
                            }
                        } else if effects.category == 4 {
                            ForEach([EffectChoice(key: "", name: "无")] + Effects.lipsticks.map(\.choice)) { item in
                                choice(item.name, id: "lipstick-" + item.key, selected: effects.snapshot.lipstick == item.key) {
                                    effects.snapshot.lipstick = item.key
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
                    }.padding(.horizontal, 2).frame(height: 34)
                }.accessibilityIdentifier("effect-options")
                    .onChange(of: selectedID) { id in withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) } }
                    .onAppear { proxy.scrollTo(selectedID, anchor: .center) }
            }.frame(height: 36)
            HStack(spacing: 4) {
                HStack(spacing: 0) {
                    ForEach(Array(["美肤", "美型", "妆容", "滤镜", "口红"].enumerated()), id: \.offset) { index, name in
                        Button { effects.category = index } label: {
                            Text(name).font(.system(size: 13, weight: effects.category == index ? .bold : .regular))
                                .foregroundColor(effects.category == index ? accent : .secondary).frame(maxWidth: .infinity).frame(height: 32)
                        }.accessibilityIdentifier("effect-category-\(index)").accessibilityAddTraits(effects.category == index ? .isSelected : [])
                    }
                }
                Button("人脸设置") { settingsPresented = true }.font(.system(size: 10)).foregroundColor(accent)
                    .padding(.horizontal, 8).frame(height: 24).background(Color(red: 0.17, green: 0.20, blue: 0.18).opacity(0.65)).cornerRadius(12)
                    .accessibilityIdentifier("face-settings")
            }.frame(height: 34)
        }.sheet(isPresented: $settingsPresented) { FaceSettings(effects: effects) }
    }
    private func choice(_ name: String, id: String, selected: Bool, adjusted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name).font(.system(size: 11)).lineLimit(1).fixedSize().padding(.horizontal, 11).frame(minWidth: 46).frame(height: 28)
                .foregroundColor(selected ? ink : .white).background(selected ? accent : Color(red: 0.17, green: 0.20, blue: 0.18).opacity(0.55)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(adjusted && !selected ? accent : .clear, lineWidth: 1))
        }.id(id).accessibilityIdentifier(id).accessibilityLabel(adjusted ? "\(name)，已调整" : name)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct CompareControl: View {
    @ObservedObject var effects: EffectsStore
    var identifier = "compare-original"
    var body: some View {
        Text(effects.snapshot.original ? "正在查看原图" : "按住对比原图").font(.system(size: 11, weight: .bold))
            .foregroundColor(ink).frame(maxWidth: .infinity, maxHeight: .infinity).background(accent.opacity(0.88)).cornerRadius(14).contentShape(Rectangle())
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
