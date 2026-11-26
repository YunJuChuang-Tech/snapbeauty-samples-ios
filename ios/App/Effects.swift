import Foundation
import Combine
import CryptoKit

struct EffectParameter: Identifiable {
    let index: Int
    let name: String
    var neutral: Float = 0
    var id: Int { index }
}

struct EffectChoice: Identifiable, Equatable {
    let key: String
    let name: String
    var makeupFilter: String = ""
    var id: String { key }
}

enum Effects {
    static let lipsticks: [(choice: EffectChoice, rgba: [Float])] = [
        (.init(key: "coral", name: "珊瑚色"), [0.611, 0.352, 0.352, 0.500]),
        (.init(key: "grapefruit", name: "西柚色"), [0.752, 0.267, 0.231, 0.543]),
        (.init(key: "rosewood", name: "豆沙粉"), [0.713, 0.374, 0.409, 0.517]),
        (.init(key: "tangerine", name: "元气橘"), [0.786, 0.326, 0.252, 0.629]),
        (.init(key: "vintage", name: "复古红"), [0.476, 0.018, 0.025, 0.777])
    ]
    static let skin = [EffectParameter(index: 0, name: "磨皮"), .init(index: 1, name: "美白"), .init(index: 2, name: "红润"),
        .init(index: 38, name: "眼妆"),
        .init(index: 28, name: "锐化"), .init(index: 29, name: "清晰"), .init(index: 30, name: "祛斑痘"),
        .init(index: 31, name: "亮眼"), .init(index: 32, name: "美牙"), .init(index: 33, name: "去黑眼圈"),
        .init(index: 34, name: "去法令纹"), .init(index: 35, name: "五官立体")]
    static let shape = [EffectParameter(index: 3, name: "瘦脸"), .init(index: 4, name: "V 脸"), .init(index: 5, name: "窄脸"),
        .init(index: 6, name: "短脸"), .init(index: 7, name: "小脸"), .init(index: 8, name: "颧骨"), .init(index: 9, name: "下颌骨"),
        .init(index: 10, name: "大眼"), .init(index: 11, name: "圆眼"), .init(index: 12, name: "下巴", neutral: 0.5),
        .init(index: 13, name: "额头", neutral: 0.5), .init(index: 14, name: "瘦鼻"), .init(index: 15, name: "嘴型", neutral: 0.5),
        .init(index: 16, name: "唇厚", neutral: 0.5), .init(index: 17, name: "眼睛高度", neutral: 0.5), .init(index: 18, name: "开眼角"),
        .init(index: 19, name: "眼睑下至"), .init(index: 20, name: "眼距", neutral: 0.5), .init(index: 21, name: "眼睛倾斜", neutral: 0.5),
        .init(index: 22, name: "鼻长", neutral: 0.5), .init(index: 23, name: "人中", neutral: 0.5), .init(index: 24, name: "微笑嘴角"),
        .init(index: 25, name: "眉高", neutral: 0.5), .init(index: 26, name: "眉间距", neutral: 0.5), .init(index: 27, name: "眉毛粗细", neutral: 0.5)]
    // Both platforms read the same names and public IDs from the original-artwork manifest.
    static let styles: [EffectChoice] = {
        struct Manifest: Decodable {
            struct Style: Decodable { let key: String; let name: String; let filter: String }
            let styles: [Style]
        }
        let url = Bundle.main.bundleURL.appendingPathComponent("Assets/sample_makeup/manifest.json")
        guard let data = try? Data(contentsOf: url), let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
            return [.init(key: "", name: "无妆")]
        }
        return [.init(key: "", name: "无妆")] + manifest.styles.map { .init(key: $0.key, name: $0.name, makeupFilter: $0.filter) }
    }()

    static func filters(at assets: URL) -> [EffectChoice] {
        let families = ["bright": "明亮", "rose": "玫瑰", "stylized": "个性", "mono": "黑白", "cool": "冷调",
                        "peach": "蜜桃", "warm": "暖调", "fresh": "清新", "muted": "柔灰", "natural": "自然"]
        // SDK built-in LUTs plus the CC BY-SA host filters this app registers itself (host-filters/luts).
        let files = ["snapbeauty/luts", "host-filters/luts"].flatMap {
            (try? FileManager.default.contentsOfDirectory(at: assets.appendingPathComponent($0), includingPropertiesForKeys: nil)) ?? []
        }
        return [.init(key: "", name: "原色")] + files.filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.map {
            let key = $0.deletingPathExtension().lastPathComponent
            let prefix = String(key.prefix { !$0.isNumber })
            return EffectChoice(key: key, name: (families[prefix] ?? "光谱") + " " + key.dropFirst(prefix.count))
        }
    }
}

struct EffectSnapshot: Equatable {
    var values: [Float] = {
        var values = [Float](repeating: 0, count: 40)
        for parameter in Effects.skin + Effects.shape { values[parameter.index] = parameter.neutral }
        values[0] = 0.6; values[1] = 0.48; values[2] = 0.1
        values[29] = 0.12; values[30] = 0.38; values[31] = 0.28
        values[33] = 0.45; values[34] = 0.35; values[35] = 0.28
        values[36] = 0.6; values[37] = 0.6; values[38] = 0.9
        return values
    }()
    static func malePreset() -> EffectSnapshot {
        var s = EffectSnapshot()
        s.values[0] = 0.65; s.values[1] = 0.38; s.values[2] = 0.12
        s.values[3] = 0.24; s.values[4] = 0.16; s.values[7] = 0.15; s.values[10] = 0.18; s.values[14] = 0.14
        s.values[28] = 0.22; s.values[29] = 0.06; s.values[30] = 0.48; s.values[31] = 0.28
        s.values[33] = 0.55; s.values[34] = 0.35; s.values[35] = 0.18; s.values[38] = 0.4
        s.style = ""; s.filter = ""; s.filterFollowsMakeup = false
        s.values[37] = 0.0
        s.lipstick = "coral"; s.lipstickAmounts["coral"] = 0.26
        return s
    }
    var style = Effects.styles.dropFirst().first?.key ?? ""
    var filter = Effects.styles.dropFirst().first?.makeupFilter ?? ""
    var filterFollowsMakeup = true
    mutating func selectStyle(_ key: String) {
        style = key
        guard let choice = Effects.styles.first(where: { $0.key == key }), !key.isEmpty else {
            if filterFollowsMakeup { filter = "" }
            filterFollowsMakeup = false
            return
        }
        filter = choice.makeupFilter; values[37] = values[36]; filterFollowsMakeup = true
    }
    mutating func selectFilter(_ key: String) { filter = key; filterFollowsMakeup = false }
    mutating func setAmount(_ index: Int, _ value: Float) {
        let clamped = value.isFinite ? min(1, max(0, value)) : 0
        values[index] = clamped
        if index == 36 && filterFollowsMakeup { values[37] = clamped }
        if index == 37 { filterFollowsMakeup = false }
    }
    var lipstick = ""
    var lipstickAmounts: [String: Float] = [:]
    var lipstickAmount: Float { lipstickAmounts[lipstick] ?? 0.6 }
    var original = false
    var sdkValues: [NSNumber] {
        var packed = values; packed[0] *= 6
        let shade = Effects.lipsticks.first { $0.choice.key == lipstick }
        packed += (shade?.rgba ?? [0, 0, 0, 0]) + [shade == nil ? 0 : lipstickAmount]
        return packed.map { NSNumber(value: $0) }
    }
}

final class EffectsStore: ObservableObject {
    @Published var snapshot = EffectSnapshot()
    @Published var malePreset = false
    @Published var category = 0
    @Published var selectedSkin = 0
    @Published var selectedShape = 3
    let assets: URL
    let filters: [EffectChoice]
    let resourceError: String?
    var selectedIndex: Int { category == 0 ? selectedSkin : category == 1 ? selectedShape : category == 2 ? 36 : 37 }
    var currentParameter: EffectParameter? { (Effects.skin + Effects.shape).first { $0.index == selectedIndex } }
    var currentTitle: String { category == 2 ? "妆容浓度" : category == 3 ? "滤镜" : category == 4 ? "口红" : currentParameter?.name ?? "强度" }
    var amountEnabled: Bool { category < 2 || (category == 2 ? !snapshot.style.isEmpty : category == 3 ? !snapshot.filter.isEmpty : !snapshot.lipstick.isEmpty) }
    var adjustedCount: Int { (Effects.skin + Effects.shape).filter { adjusted($0.index) }.count }
    func currentDefaults() -> EffectSnapshot { malePreset ? EffectSnapshot.malePreset() : EffectSnapshot() }
    func adjusted(_ index: Int) -> Bool { abs(snapshot.values[index] - currentDefaults().values[index]) > 0.005 }
    func displayValue() -> String {
        let number = Int(((category == 4 ? snapshot.lipstickAmount : snapshot.values[selectedIndex]) * 100).rounded())
        if currentParameter?.neutral == 0.5 {
            let signed = number - 50
            return signed > 0 ? "+\(signed)" : "\(signed)"
        }
        return "\(number)"
    }
    func restoreCurrent() { snapshot.values[selectedIndex] = currentDefaults().values[selectedIndex] }
    func applyGenderPreset(_ male: Bool) { malePreset = male; snapshot = currentDefaults() }
    func reset() { snapshot = currentDefaults(); selectedSkin = 0; selectedShape = 3 }
    init(bundle: Bundle = .main) {
        assets = (try? SampleSPMResources.assets.get()) ?? bundle.bundleURL.appendingPathComponent("Assets")
        filters = Effects.filters(at: assets)
        do { _ = try SampleSPMResources.assets.get(); try Self.validateAssets(assets); resourceError = nil }
        catch { resourceError = "美妆资源不完整，请安装完整示例。" }
    }
    static func validateAssets(_ root: URL) throws {
        struct Manifest: Decodable { struct Entry: Decodable { let sha256: String }; let files: [String: Entry] }
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("sample_makeup/manifest.json")))
        guard manifest.files.count == 53 else { throw CocoaError(.fileReadCorruptFile) }
        for (path, entry) in manifest.files {
            guard path.hasPrefix("makeup/"), !path.contains("..") else { throw CocoaError(.fileReadCorruptFile) }
            let bytes = try Data(contentsOf: root.appendingPathComponent(path))
            guard SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == entry.sha256 else { throw CocoaError(.fileReadCorruptFile) }
        }
    }
}

extension NSLock {
    func locked<T>(_ action: () throws -> T) rethrows -> T { lock(); defer { unlock() }; return try action() }
}
