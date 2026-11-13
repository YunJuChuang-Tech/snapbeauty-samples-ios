import SnapBeautyResources
import XCTest
import CoreVideo
import UIKit
import CryptoKit
import Metal
@testable import SnapBeautySamples

final class SampleTests: XCTestCase {
    func testRemotePackageResources() throws {
        let root = try SampleSPMResources.assets.get()
        try EffectsStore.validateAssets(root)
        XCTAssertEqual(BeautyFrameProcessor.sdkVersion(), "1.3.0")
        XCTAssertEqual(Effects.filters(at: root).count, 28)
        XCTAssertTrue(FileManager.default.fileExists(atPath: SnapBeautyResources.shaders.appendingPathComponent("snapbeauty.metallib").path))
        let processor = try XCTUnwrap(BeautyFrameProcessor(assets: root.path, shaders: SnapBeautyResources.shaders.path))
        guard BeautyFrameProcessor.licenseUsable() else { throw XCTSkip("Frame processing requires a valid app-bound SDK license") }
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:], kCVPixelBufferMetalCompatibilityKey as String: true] as CFDictionary, &buffer), kCVReturnSuccess)
        let input = try XCTUnwrap(buffer)
        let output = try processor.process(input, values: EffectSnapshot().sdkValues, style: nil, filter: nil, maxFaces: 1)
        XCTAssertEqual(CVPixelBufferGetWidth(output), 64)
    }

    func testPreviewRowDirectionMirrorAndUniformScale() throws {
        var allocated: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 48, 32, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &allocated), kCVReturnSuccess)
        let frame = try XCTUnwrap(allocated)
        CVPixelBufferLockBaseAddress(frame, [])
        let pointer = CVPixelBufferGetBaseAddress(frame)!.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(frame)
        for y in 0..<32 { for x in 0..<48 {
            let i = y * stride + x * 4
            pointer[i] = (x - 24) * (x - 24) + (y - 16) * (y - 16) <= 36 ? 240 : 40
            pointer[i + 1] = y < 16 ? 80 : 130; pointer[i + 2] = x < 24 ? 110 : 170; pointer[i + 3] = 255
        } }
        CVPixelBufferUnlockBaseAddress(frame, [])
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let queue = try XCTUnwrap(device.makeCommandQueue())
        let context = CIContext(mtlDevice: device)
        for mirror in [false, true] {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 64, height: 64, mipmapped: false)
            descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
            let command = try XCTUnwrap(queue.makeCommandBuffer())
            context.render(PreviewGeometry.image(frame, mirror: mirror, size: CGSize(width: 64, height: 64)), to: texture,
                commandBuffer: command, bounds: CGRect(x: 0, y: 0, width: 64, height: 64), colorSpace: CGColorSpaceCreateDeviceRGB())
            command.commit(); command.waitUntilCompleted()
            XCTAssertEqual(command.status, .completed)
            var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
            texture.getBytes(&pixels, bytesPerRow: 64 * 4, from: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0)
            // CI's Metal readback has bottom-origin rows. The separate screen screenshot test
            // verifies actual top-origin presentation; mirror still changes X only.
            XCTAssertEqual(Double(pixels[(8 * 64 + 8) * 4 + 1]), 130, accuracy: 2)
            XCTAssertEqual(Double(pixels[(8 * 64 + 8) * 4 + 2]), mirror ? 170 : 110, accuracy: 2)
            XCTAssertEqual(Double(pixels[(56 * 64 + 56) * 4 + 1]), 80, accuracy: 2)
            // Measure the whole circle: a mirrored discrete center can fall beside the fixed center scanline.
            let mask = (0..<(64 * 64)).filter { pixels[$0 * 4] > 140 }
            let xs = mask.map { $0 % 64 }, ys = mask.map { $0 / 64 }
            let horizontal = try XCTUnwrap(xs.max()) - XCTUnwrap(xs.min()) + 1
            let vertical = try XCTUnwrap(ys.max()) - XCTUnwrap(ys.min()) + 1
            XCTAssertGreaterThan(horizontal, 20)
            XCTAssertLessThanOrEqual(abs(horizontal - vertical), 1, "A circle stays round after center cropping a non-square frame")
        }
    }
    func testFourScenesAndParameterContract() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "ai.snapbeauty.samples")
        XCTAssertEqual(SampleScene.allCases.map(\.name), ["相机美颜", "腾讯云 TRTC", "声网 Agora", "即构 ZEGO"])
        XCTAssertEqual(Effects.skin.count, 11)
        XCTAssertEqual(Effects.shape.count, 25)
        XCTAssertEqual(Set((Effects.skin + Effects.shape).map(\.index)), Set(0..<36))
        let snapshot = EffectSnapshot()
        XCTAssertEqual(snapshot.sdkValues.count, 40)
        XCTAssertEqual(snapshot.sdkValues[0].floatValue, 2.1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.style, "dawn")
        XCTAssertFalse(snapshot.original)
        for item in Effects.shape where item.neutral == 0.5 { XCTAssertEqual(snapshot.values[item.index], 0.5) }
    }

    func testAndroidControlSelectionRestoreAndSignedValues() {
        let effects = EffectsStore()
        effects.snapshot.values[0] = 0.8
        XCTAssertTrue(effects.adjusted(0)); XCTAssertEqual(effects.adjustedCount, 1)
        effects.restoreCurrent()
        XCTAssertEqual(effects.snapshot.values[0], 0.35)
        XCTAssertFalse(effects.adjusted(0))
        effects.category = 1; effects.selectedShape = 12
        XCTAssertEqual(effects.displayValue(), "0")
        effects.snapshot.values[12] = 0.8; XCTAssertEqual(effects.displayValue(), "+30")
        effects.snapshot.values[12] = 0.2; XCTAssertEqual(effects.displayValue(), "-30")
        effects.category = 0; effects.selectedSkin = 1; effects.category = 1
        XCTAssertEqual(effects.selectedIndex, 12)
        effects.restoreCurrent(); XCTAssertEqual(effects.displayValue(), "0")
        effects.category = 2; effects.snapshot.style = ""; XCTAssertFalse(effects.amountEnabled)
        effects.snapshot.style = "dawn"; XCTAssertTrue(effects.amountEnabled)
        effects.category = 3; effects.snapshot.filter = ""; XCTAssertFalse(effects.amountEnabled)
        effects.reset()
        XCTAssertEqual(effects.snapshot, EffectSnapshot())
        XCTAssertEqual(effects.selectedSkin, 0); XCTAssertEqual(effects.selectedShape, 3)
    }

    func testSharedMakeupPresetsAndFilterOverrides() throws {
        let filters = Set(EffectsStore().filters.map(\.key))
        XCTAssertEqual(Effects.styles.count, 16)
        XCTAssertEqual(Effects.styles.first { $0.key == "dawn" }?.name, "晨曦")
        XCTAssertEqual(EffectSnapshot().filter, "rose3")
        for choice in Effects.styles where !choice.key.isEmpty {
            XCTAssertTrue(filters.contains(choice.makeupFilter), "Preset LUT is shipped: \(choice.key)")
            var paired = EffectSnapshot(); paired.selectStyle(choice.key); paired.setAmount(36, 0.8)
            XCTAssertEqual(paired.filter, choice.makeupFilter); XCTAssertEqual(paired.values[37], 0.8)
            var manual = paired; manual.selectFilter("warm1"); manual.setAmount(37, 0.37); manual.setAmount(36, 0.2)
            XCTAssertEqual(manual.filter, "warm1"); XCTAssertEqual(manual.values[37], 0.37)
            paired.selectStyle(""); XCTAssertEqual(paired.filter, "")
            manual.selectStyle(""); XCTAssertEqual(manual.filter, "warm1")
            manual.selectStyle(choice.key); XCTAssertEqual(manual.filter, choice.makeupFilter)
        }
    }

    func testRoomDefaultsRememberOnlyNonSecretFields() {
        let scene = SampleScene.agora
        let defaults = UserDefaults.standard
        let keys = ["appID", "room", "user"].map { "scene.\(scene.rawValue).\($0)" }
        let previous = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, previous) { if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) } } }
        RoomFields(appID: "test-app", room: "test-room", user: "42", token: "never-store-test-token", microphone: true).save(for: scene)
        let restored = RoomFields.saved(for: scene, microphone: false)
        XCTAssertEqual(restored.appID, "test-app"); XCTAssertEqual(restored.room, "test-room"); XCTAssertEqual(restored.user, "42")
        XCTAssertEqual(restored.token, ""); XCTAssertFalse(restored.microphone)
        XCTAssertFalse(defaults.dictionaryRepresentation().values.contains { ($0 as? String) == "never-store-test-token" })
    }

    func testCompleteOriginalAssetsAndNativeSDKLoading() throws {
        let root = try SampleSPMResources.assets.get()
        try EffectsStore.validateAssets(root)
        XCTAssertEqual(Effects.styles.count, 16)
        XCTAssertGreaterThan(Effects.filters(at: root).count, 1)
        let versions = SampleRTCSession.sdkVersions()
        XCTAssertTrue(versions["TRTC"]?.hasPrefix("13.5") == true)
        XCTAssertTrue(versions["Agora"]?.hasPrefix("4.6.4") == true)
        XCTAssertTrue(versions["ZEGO"]?.hasPrefix("3.25") == true)
    }

    func testRoomValidationRejectsInvalidInputBeforeSDKCreation() throws {
        var fields = RoomFields(appID: "1", room: "1001", user: "user_a", token: "placeholder-only", microphone: false)
        XCTAssertNoThrow(try fields.validated(for: .trtc))
        XCTAssertNoThrow(try fields.validated(for: .zego))
        XCTAssertFalse(try fields.validated(for: .trtc).microphone)
        fields.appID = "0"; XCTAssertThrowsError(try fields.validated(for: .trtc))
        fields.appID = "1"; fields.room = "0"; XCTAssertThrowsError(try fields.validated(for: .trtc))
        fields.room = "room"; fields.user = "bad user"; XCTAssertThrowsError(try fields.validated(for: .zego))
        fields = RoomFields(appID: String(repeating: "a", count: 32), room: "sample", user: "123", token: "placeholder-only", microphone: false)
        XCTAssertNoThrow(try fields.validated(for: .agora))
        fields.user = "-1"; XCTAssertThrowsError(try fields.validated(for: .agora))
        fields.user = "1"; fields.token = " "; XCTAssertThrowsError(try fields.validated(for: .agora))
    }

    func testActualMetalOutputAndInputOwnership() throws {
        guard BeautyFrameProcessor.licenseUsable() else { throw XCTSkip("Frame processing requires a valid app-bound SDK license") }
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:], kCVPixelBufferMetalCompatibilityKey as String: true] as CFDictionary, &buffer), kCVReturnSuccess)
        let input = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(input, [])
        let bytes = CVPixelBufferGetBaseAddress(input)!.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(input)
        for y in 0..<64 { for x in 0..<64 {
            let index = y * stride + x * 4
            bytes[index] = 65; bytes[index + 1] = y < 32 ? 80 : 135; bytes[index + 2] = x < 32 ? 110 : 170; bytes[index + 3] = 255
        } }
        CVPixelBufferUnlockBaseAddress(input, [])
        let original = rows(input)
        let processor = try XCTUnwrap(BeautyFrameProcessor(assets: try SampleSPMResources.assets.get().path,
            shaders: SnapBeautyResources.shaders.path))
        XCTAssertEqual(BeautyFrameProcessor.sdkVersion(), "1.3.0")
        XCTAssertThrowsError(try processor.process(input, values: EffectSnapshot().sdkValues, style: nil, filter: nil, maxFaces: 4))
        var neutral = EffectSnapshot()
        for item in Effects.skin + Effects.shape { neutral.values[item.index] = item.neutral }
        neutral.style = ""; neutral.values[36] = 0; neutral.values[37] = 0
        let output = try XCTUnwrap(processor.process(input, values: neutral.sdkValues, style: nil, filter: nil, maxFaces: 1))
        let neutralRows = rows(output)
        XCTAssertTrue(BeautyFrameProcessor.licenseUsable())
        XCTAssertEqual(neutralRows, original, "Licensed neutral output has no protection mark")
        neutral.values[1] = 1
        let white = try XCTUnwrap(processor.process(input, values: neutral.sdkValues, style: nil, filter: nil, maxFaces: 1))
        XCTAssertNotEqual(rows(white), neutralRows, "The app-bound license enables actual whitening")
        XCTAssertEqual(rows(input), original, "The input remains available for original comparison")
        XCTAssertEqual(rows(output), neutralRows, "Previously returned output owns its pixels across later frames")
        let pipeline = BeautyPipeline()
        var held = EffectSnapshot(); held.values[1] = 1; held.original = true
        pipeline.update(held)
        XCTAssertTrue(pipeline.process(input).0 === input, "Holding compare shows the camera frame itself")
        held.original = false; pipeline.update(held)
        XCTAssertFalse(pipeline.process(input).0 === input, "Releasing compare restores the effect")


    }

    func testAllMakeupStylesOnLocalFace() throws {
        let fixture = Bundle(for: Self.self).bundleURL.appendingPathComponent("Verification/portrait.jpg")
        guard let photo = UIImage(contentsOfFile: fixture.path)?.cgImage else { throw XCTSkip("No local face fixture supplied; source images are never distributed with the app") }
        guard BeautyFrameProcessor.licenseUsable() else { throw XCTSkip("Full makeup output requires an app-bound SDK license") }
        let metadata = fixture.deletingLastPathComponent().appendingPathComponent("regions.json")
        let regions = (try? JSONSerialization.jsonObject(with: Data(contentsOf: metadata))) as? [String: Any]
        let boxes = regions?["regions"] as? [String: [Int]]
        var allocated: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, photo.width, photo.height, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:], kCVPixelBufferMetalCompatibilityKey as String: true] as CFDictionary, &allocated), kCVReturnSuccess)
        let input = try XCTUnwrap(allocated)
        CVPixelBufferLockBaseAddress(input, [])
        let context = try XCTUnwrap(CGContext(data: CVPixelBufferGetBaseAddress(input), width: photo.width, height: photo.height,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(input), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue))
        context.draw(photo, in: CGRect(x: 0, y: 0, width: photo.width, height: photo.height))
        CVPixelBufferUnlockBaseAddress(input, [])
        let original = rows(input)
        let processor = try XCTUnwrap(BeautyFrameProcessor(assets: try SampleSPMResources.assets.get().path,
            shaders: SnapBeautyResources.shaders.path))
        var snapshot = EffectSnapshot()
        for item in Effects.skin + Effects.shape { snapshot.values[item.index] = item.neutral }
        snapshot.values[36] = 1; snapshot.filter = ""
        var hashes = Set<String>()
        let evidence = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("makeup-verification")
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        func save(_ frame: CVPixelBuffer, _ name: String) throws {
            let cg = try XCTUnwrap(CIContext().createCGImage(CIImage(cvPixelBuffer: frame), from: CGRect(x: 0, y: 0, width: photo.width, height: photo.height)))
            try UIImage(cgImage: cg).pngData()?.write(to: evidence.appendingPathComponent(name + ".png"))
        }
        try save(input, "original")
        for choice in Effects.styles where !choice.key.isEmpty {
            var output = input
            for _ in 0..<12 { output = try processor.process(input, values: snapshot.sdkValues, style: choice.key, filter: nil, maxFaces: 1) }
            XCTAssertGreaterThan(processor.faceCount, 0, "A real face is detected for \(choice.key)")
            let full = rows(output)
            XCTAssertNotEqual(full, original, "Makeup changes real face pixels: \(choice.key)")
            XCTAssertTrue(hashes.insert(SHA256.hash(data: full).map { String(format: "%02x", $0) }.joined()).inserted, "Distinct style pixels: \(choice.key)")
            if let boxes {
                for (region, box) in boxes {
                    var changed = 0
                    for y in box[1]..<box[3] { for x in box[0]..<box[2] {
                        let offset = (y * photo.width + x) * 4
                        if (0..<3).contains(where: { abs(Int(full[offset + $0]) - Int(original[offset + $0])) > 12 }) { changed += 1 }
                    } }
                    if region == "forehead" { XCTAssertEqual(changed, 0, "No forehead pigment: \(choice.key)") }
                    else if region.contains("Cheek") && ["neon", "ink"].contains(choice.key) { XCTAssertLessThan(changed, 20) }
                    else { XCTAssertGreaterThan(changed, 20, "\(choice.key) reaches \(region)") }
                }
            }
            try save(output, choice.key)
            snapshot.values[36] = 0.4
            let partial = try processor.process(input, values: snapshot.sdkValues, style: choice.key, filter: nil, maxFaces: 1)
            XCTAssertNotEqual(rows(partial), full); XCTAssertNotEqual(rows(partial), original)
            XCTAssertEqual(rows(output), full, "Previous output owns its pixels after further rendering")
            snapshot.values[36] = 0
            let zero = try processor.process(input, values: snapshot.sdkValues, style: nil, filter: nil, maxFaces: 1)
            XCTAssertEqual(rows(zero), original, "Zero makeup restores source bytes")
            XCTAssertEqual(rows(input), original, "Input is not mutated")
            var combined = snapshot; combined.selectStyle(choice.key); combined.setAmount(36, 1)
            let graded = try processor.process(input, values: combined.sdkValues, style: choice.key, filter: combined.filter, maxFaces: 1)
            XCTAssertNotEqual(rows(graded), full, "Whole-look preset adds actual color grading: \(choice.key)")
            combined.setAmount(36, 0)
            let cleared = try processor.process(input, values: combined.sdkValues, style: nil, filter: combined.filter, maxFaces: 1)
            XCTAssertEqual(rows(cleared), original, "Zero linked strength clears makeup and LUT")
            snapshot.values[36] = 1
        }
    }

    private func rows(_ buffer: CVPixelBuffer) -> Data {
        CVPixelBufferLockBaseAddress(buffer, .readOnly); defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let base = CVPixelBufferGetBaseAddress(buffer)!
        var output = Data()
        for y in 0..<CVPixelBufferGetHeight(buffer) {
            output.append(base.advanced(by: y * CVPixelBufferGetBytesPerRow(buffer)).assumingMemoryBound(to: UInt8.self), count: CVPixelBufferGetWidth(buffer) * 4)
        }
        return output
    }
}


extension SampleTests {
    func testProcessingFailureStaysOnOriginalUntilExplicitRetry() throws {
        var source: CVPixelBuffer?; var effect: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, 32, 32, kCVPixelFormatType_32BGRA, attributes, &source)
        CVPixelBufferCreate(kCFAllocatorDefault, 32, 32, kCVPixelFormatType_32BGRA, attributes, &effect)
        let input = try XCTUnwrap(source), processed = try XCTUnwrap(effect)
        var calls = 0
        let pipeline = BeautyPipeline(operation: { _, _ in
            calls += 1
            if calls == 2 { throw NSError(domain: "ai.snapbeauty.engine", code: 4) }
            return (processed, "效果帧")
        })
        XCTAssertTrue(pipeline.process(input).0 === processed)
        let failure = pipeline.process(input)
        XCTAssertTrue(failure.0 === input)
        XCTAssertEqual(failure.1, "美颜处理失败，已显示原图，请重试")
        for _ in 0..<30 {
            let next = pipeline.process(input)
            XCTAssertTrue(next.0 === input, "Failures must not alternate original and effect frames")
            XCTAssertEqual(next.1, failure.1)
        }
        XCTAssertEqual(calls, 2, "No automatic per-frame retry after a rendering failure")
        XCTAssertTrue(pipeline.isBypassed)
        pipeline.resetTracking()
        XCTAssertFalse(pipeline.isBypassed)
        XCTAssertTrue(pipeline.process(input).0 === processed)
        XCTAssertEqual(calls, 3, "Explicit retry resumes effect processing")
    }

    func testSerializedFramesMayMoveAcrossOSThreads() throws {
        guard BeautyFrameProcessor.licenseUsable() else { throw XCTSkip("Frame processing requires a valid app-bound SDK license") }
        var allocated: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:], kCVPixelBufferMetalCompatibilityKey as String: true] as CFDictionary, &allocated), kCVReturnSuccess)
        let input = try XCTUnwrap(allocated)
        CVPixelBufferLockBaseAddress(input, [])
        let base = CVPixelBufferGetBaseAddress(input)!.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(input)
        for y in 0..<64 { for x in 0..<64 {
            let at = y * stride + x * 4
            base[at] = 65; base[at + 1] = 80; base[at + 2] = 110; base[at + 3] = 255
        } }
        CVPixelBufferUnlockBaseAddress(input, [])
        let original = rows(input)
        let processor = try XCTUnwrap(BeautyFrameProcessor(assets: try SampleSPMResources.assets.get().path,
            shaders: SnapBeautyResources.shaders.path))
        XCTAssertTrue(BeautyFrameProcessor.licenseUsable(), "The regression uses a valid license")
        var settings = EffectSnapshot()
        for item in Effects.skin + Effects.shape { settings.values[item.index] = item.neutral }
        settings.values[1] = 1; settings.style = ""; settings.values[36] = 0; settings.values[37] = 0
        for frame in 0..<8 {
            let completed = expectation(description: "Frame on a distinct caller thread")
            Thread.detachNewThread { [self, settings] in
                autoreleasepool {
                    do {
                        let output = try processor.process(input, values: settings.sdkValues, style: nil, filter: nil, maxFaces: 1)
                        XCTAssertNotEqual(rows(output), original, "Licensed effects remain active across OS thread changes")
                        if frame == 3 { processor.resetTracking() }
                    } catch { XCTFail("Serialized frame \(frame) failed with valid authorization: \(error)") }
                    completed.fulfill()
                }
            }
            wait(for: [completed], timeout: 10)
        }
        XCTAssertTrue(BeautyFrameProcessor.licenseUsable(), "Render errors must not change the authorization state")
    }
}
