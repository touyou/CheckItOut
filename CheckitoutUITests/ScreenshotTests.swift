//
//  ScreenshotTests.swift
//  CheckitoutUITests
//
//  Captures the App Store submission screenshots. Not a behaviour test: it
//  drives the app to each screen and attaches an image.
//  `scripts/capture_screenshots.sh` runs it per destination and locale and
//  extracts the attachments.
//

import XCTest

final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    /// `-uitest-ephemeral-store` keeps SwiftData in memory and
    /// `-uitest-screenshot-fixture` seeds the board and fakes a recording (see
    /// `ScreenshotFixture` in the app). The language comes from
    /// `xcodebuild -testLanguage`, not from launch arguments.
    private let launchArguments = [
        "-uitest-ephemeral-store",
        "-uitest-screenshot-fixture",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = launchArguments
        app.launch()
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        app = nil
    }

    // MARK: - Capture

    /// Attaches the device's framebuffer (exactly the pixel size App Store
    /// Connect asks for) under a name the extraction script can order by.
    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        // In landscape the framebuffer is still portrait-shaped and the
        // orientation lives only in the image's metadata, which the PNG of
        // `XCTAttachment(screenshot:)` drops — the shot would come out
        // sideways. Redraw it upright instead.
        let attachment = XCUIDevice.shared.orientation.isLandscape
            ? pngAttachment(screenshot.image.redrawnUpright())
            : XCTAttachment(screenshot: screenshot)
        attachment.name = name
        // Attachments are discarded on success by default, and every
        // screenshot run succeeds — without this the run produces nothing.
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pngAttachment(_ image: UIImage) -> XCTAttachment {
        XCTAttachment(data: image.pngData() ?? Data(), uniformTypeIdentifier: "public.png")
    }

    /// Lets layout morphs and sheet presentation finish before a capture.
    private func settle() {
        Thread.sleep(forTimeInterval: 1.5)
    }

    // MARK: - Screens

    @MainActor
    func testCaptureScreenshots() throws {
        // 1. The board in play mode, pads filled by the fixture.
        let modePicker = app.segmentedControls["modePicker"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 30), "Main screen should show the mode picker")
        XCTAssertTrue(app.staticTexts["バスドラ"].firstMatch.waitForExistence(timeout: 10),
                      "Screenshot fixture should have seeded the sounds")
        settle()
        capture("01-play")

        // 2. Edit mode, with an unassigned sound picked and ready to drop on a pad.
        modePicker.buttons["編集"].tap()
        let row = app.collectionViews["soundList"].staticTexts["笑い声"]
        if !row.isHittable {
            app.collectionViews["soundList"].swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The unassigned fixture sound should be listed")
        row.tap()
        settle()
        capture("02-edit")
        modePicker.buttons["再生"].tap()
        // Scroll the list back to the top so the next shots start from the
        // first sounds again.
        app.collectionViews["soundList"].swipeDown()
        app.collectionViews["soundList"].swipeDown()

        // 3. The recording panel, showing the fixture's finished take.
        app.buttons["recordButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["waveform"].waitForExistence(timeout: 10),
                      "Record button should open the recording panel")
        settle()
        capture("03-record")
        app.buttons["閉じる"].firstMatch.tap()
        XCTAssertTrue(modePicker.waitForExistence(timeout: 10), "Recording panel should dismiss")

        // 4. Landscape, where the pads and the list sit side by side.
        // Skipped where the app doesn't turn with the device (e.g. iPhone Duo
        // unfolded), since it would only repeat the first shot.
        XCUIDevice.shared.orientation = .landscapeLeft
        settle()
        let window = app.windows.firstMatch.frame
        if window.width > window.height {
            capture("04-landscape")
        }
    }
}

private extension UIImage {
    /// Bakes `imageOrientation` into the pixels, keeping the pixel scale so
    /// the output stays at the device's native resolution.
    func redrawnUpright() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(at: .zero)
        }
    }
}
