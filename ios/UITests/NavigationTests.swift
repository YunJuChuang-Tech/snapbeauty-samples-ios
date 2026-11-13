import XCTest

final class NavigationTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    func testActualScreenHeadAndChinDirection() throws {
        for mirror in [false, true] {
            let app = XCUIApplication()
            app.launchEnvironment = ["SAMPLE_PREVIEW_CHART": "1", "SAMPLE_PREVIEW_MIRROR": mirror ? "1" : "0"]
            app.launch()
            // Wait for the first Core Image command to be presented by the real layer.
            let ready = expectation(description: "First screen presentation")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { ready.fulfill() }
            wait(for: [ready], timeout: 4)
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = mirror ? "screen-front-mirrored" : "screen-back-unmirrored"
            attachment.lifetime = .keepAlways; add(attachment)
            let image = try XCTUnwrap(screenshot.image.cgImage)
            func pixel(_ x: CGFloat, _ y: CGFloat) throws -> [UInt8] {
                let single = try XCTUnwrap(image.cropping(to: CGRect(x: CGFloat(image.width) * x, y: CGFloat(image.height) * y, width: 1, height: 1)))
                var rgba = [UInt8](repeating: 0, count: 4)
                let context = try XCTUnwrap(CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(single, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                return rgba
            }
            let top = try pixel(0.3, 0.25), bottom = try pixel(0.7, 0.75)
            XCTAssertGreaterThan(top[0], top[2], "Head stays above chin on the actual display")
            XCTAssertGreaterThan(bottom[2], bottom[0], "Chin stays below head on the actual display")
            XCTAssertEqual(Double(top[1]), mirror ? 40 : 180, accuracy: 3, "Mirror changes X only")
            app.terminate()
        }
    }
    func testAndroidAlignedControlsAcrossFourScenes() {
        let app = XCUIApplication(); app.launch()
        for scene in 0..<4 {
            let entry = app.buttons["scene-\(scene)"]
            if !entry.isHittable { app.swipeUp() }
            XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
            XCTAssertTrue(app.buttons["scene-back"].waitForExistence(timeout: 5))
            if scene == 1 {
                XCTAssertTrue(app.buttons["start-preview"].exists)
                XCTAssertTrue(app.buttons["stop-preview"].exists)
                XCTAssertTrue(app.buttons["join-room"].exists)
                let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "android-aligned-trtc-controls"; screenshot.lifetime = .keepAlways; add(screenshot)
                app.buttons["more-effects"].tap()
            } else {
                let handle = app.buttons["effect-panel-handle"]
                XCTAssertTrue(handle.waitForExistence(timeout: 5))
                XCTAssertEqual(handle.value as? String, "已展开")
                handle.tap(); XCTAssertEqual(handle.value as? String, "已收起")
                handle.tap(); XCTAssertEqual(handle.value as? String, "已展开")
                if scene == 0 {
                    let start = app.buttons["effect-category-0"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 230)))
                    XCTAssertEqual(handle.value as? String, "已收起", "Drag from panel contents also collapses")
                    let up = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    up.press(forDuration: 0.1, thenDragTo: up.withOffset(CGVector(dx: 0, dy: -230)))
                    XCTAssertEqual(handle.value as? String, "已展开")
                }
            }
            let slider = app.sliders["effect-slider"]
            XCTAssertTrue(slider.waitForExistence(timeout: 5))
            app.buttons["effect-category-0"].tap()
            slider.adjust(toNormalizedSliderPosition: 0.8)
            XCTAssertTrue(app.buttons["restore-current"].isEnabled)
            app.buttons["restore-current"].tap()
            XCTAssertEqual(app.staticTexts["effect-amount"].label, "35")
            app.buttons["effect-category-1"].tap()
            let chin = app.buttons["parameter-12"]
            for _ in 0..<8 {
                if chin.isHittable { break }
                let strip = app.scrollViews["effect-options"]
                if chin.frame.midX < strip.frame.minX { strip.swipeRight(velocity: .slow) }
                else { strip.swipeLeft(velocity: .slow) }
            }
            XCTAssertTrue(chin.isHittable); chin.tap()
            XCTAssertEqual(app.staticTexts["effect-amount"].label, "0")
            slider.adjust(toNormalizedSliderPosition: 0.8)
            XCTAssertTrue(app.staticTexts["effect-amount"].label.hasPrefix("+"))
            app.buttons["effect-category-0"].tap(); app.buttons["effect-category-1"].tap()
            XCTAssertEqual(app.staticTexts["effect-current-name"].label, "下巴", "Each tab remembers its selected option")
            app.buttons["restore-current"].tap()
            XCTAssertEqual(app.staticTexts["effect-amount"].label, "0")
            app.buttons["effect-category-2"].tap()
            app.buttons["style-"].tap(); XCTAssertFalse(slider.isEnabled)
            app.buttons["style-dawn"].tap(); XCTAssertTrue(slider.isEnabled)
            app.buttons["compare-original"].press(forDuration: 0.3)
            XCTAssertEqual(app.buttons["compare-original"].value as? String, "效果", "Release ends original comparison")
            app.buttons["face-settings"].tap()
            XCTAssertTrue(app.navigationBars["人脸设置"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts["single-face-support"].exists)
            app.navigationBars.buttons["取消"].tap()
            app.buttons["reset-effects"].tap()
            if scene == 0 {
                let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "android-aligned-camera-controls"; attachment.lifetime = .keepAlways; add(attachment)
            }
            if scene == 1 { app.navigationBars.buttons["完成"].tap() }
            if scene != 0 {
                app.buttons["join-room"].tap()
                XCTAssertTrue(app.secureTextFields.firstMatch.waitForExistence(timeout: 3))
                XCTAssertEqual(app.secureTextFields.firstMatch.value as? String, scene == 1 ? "UserSig" : "Token")
                app.navigationBars.buttons["取消"].tap()
            }
            app.buttons["scene-back"].tap()
            XCTAssertTrue(app.buttons["scene-0"].waitForExistence(timeout: 5))
        }
    }
}
