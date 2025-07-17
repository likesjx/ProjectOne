import XCTest
import AVFoundation
@testable import ProjectOne

class AudioPlayerTests: XCTestCase {

    var audioPlayer: AudioPlayer!
    var testAudioURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        audioPlayer = AudioPlayer()

        let temporaryDirectory = FileManager.default.temporaryDirectory
        testAudioURL = temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")

        // Synchronously create a 2-second silent audio file.
        try createSilentAudioFile(url: testAudioURL, duration: 2.0)
    }

    override func tearDownWithError() throws {
        audioPlayer = nil
        if FileManager.default.fileExists(atPath: testAudioURL.path) {
            try FileManager.default.removeItem(at: testAudioURL)
        }
        try super.tearDownWithError()
    }

    /// Creates a silent audio file with a specified duration.
    /// This method uses AVAssetWriter to generate a valid M4A file with silent audio,
    /// waiting synchronously for the writing to complete to prevent race conditions in tests.
    private func createSilentAudioFile(url: URL, duration: TimeInterval) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]

        let writer = try AVAssetWriter(url: url, fileType: .m4a)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        writer.add(writerInput)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let expectation = self.expectation(description: "Wait for asset writer to finish")
        let queue = DispatchQueue(label: "mediaInputQueue")

        writerInput.requestMediaDataWhenReady(on: queue) {
            let sampleRate = 44100.0
            let totalSamples = Int(duration * sampleRate)
            let bufferSize = totalSamples * 2 // 16-bit audio

            guard let silentData = NSMutableData(length: bufferSize) else {
                XCTFail("Failed to create silent data buffer")
                expectation.fulfill()
                return
            }

            var blockBuffer: CMBlockBuffer?
            var status = CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: silentData.mutableBytes,
                blockLength: bufferSize,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: bufferSize,
                flags: 0,
                blockBufferOut: &blockBuffer)

            guard status == kCMBlockBufferNoErr, let finalBlockBuffer = blockBuffer else {
                XCTFail("Failed to create CMBlockBuffer. Status: \(status)")
                expectation.fulfill()
                return
            }

            var sampleBuffer: CMSampleBuffer?
            var asbd = AudioStreamBasicDescription(mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
            var formatDesc: CMFormatDescription?
            CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &formatDesc)

            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: Int32(sampleRate)), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
            CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: finalBlockBuffer, formatDescription: formatDesc, sampleCount: totalSamples, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer)

            if let finalSampleBuffer = sampleBuffer {
                writerInput.append(finalSampleBuffer)
            }
            
            writerInput.markAsFinished()
            writer.finishWriting {
                if writer.status == .failed {
                    XCTFail("Asset writer failed with error: \(writer.error?.localizedDescription ?? "Unknown error")")
                }
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    func testLoadAudio() {
        let expectation = self.expectation(description: "Audio loading completes")
        
        // Assuming loadAudio is asynchronous and updates properties on the main thread.
        // We observe the `isLoaded` property to fulfill the expectation.
        var cancellable: Any?
        cancellable = audioPlayer.$isLoaded.sink { isLoaded in
            if isLoaded {
                expectation.fulfill()
                cancellable?.cancel()
            }
        }

        audioPlayer.loadAudio(from: testAudioURL)

        waitForExpectations(timeout: 2.0) { error in
            if error != nil {
                XCTFail("Audio failed to load within the timeout period.")
            }
            XCTAssertTrue(self.audioPlayer.isLoaded, "Audio player should have loaded the audio file")
            XCTAssertEqual(self.audioPlayer.currentURL, self.testAudioURL, "The current URL should be the test audio URL")
            XCTAssertGreaterThan(self.audioPlayer.duration, 1.9, "The duration should be approximately 2 seconds")
        }
    }

    func testPlay() {
        audioPlayer.loadAudio(from: testAudioURL)
        // Wait for audio to load before playing
        let expectation = self.expectation(description: "Wait for load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        audioPlayer.play()
        XCTAssertTrue(audioPlayer.isPlaying, "Audio player should be playing")
    }

    func testPause() {
        audioPlayer.loadAudio(from: testAudioURL)
        // Wait for audio to load before playing
        let expectation = self.expectation(description: "Wait for load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)
        
        audioPlayer.play()
        audioPlayer.pause()
        XCTAssertFalse(audioPlayer.isPlaying, "Audio player should not be playing")
    }

    func testStop() {
        audioPlayer.loadAudio(from: testAudioURL)
        // Wait for audio to load before playing
        let expectation = self.expectation(description: "Wait for load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        audioPlayer.play()
        audioPlayer.stop()
        XCTAssertFalse(audioPlayer.isPlaying, "Audio player should not be playing")
        XCTAssertEqual(audioPlayer.currentTime, 0, "Current time should be reset to 0")
    }

    func testTogglePlayback() {
        audioPlayer.loadAudio(from: testAudioURL)
        // Wait for audio to load before toggling
        let expectation = self.expectation(description: "Wait for load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        // Start playing
        audioPlayer.togglePlayback()
        XCTAssertTrue(audioPlayer.isPlaying, "Audio player should be playing")
        
        // Pause
        audioPlayer.togglePlayback()
        XCTAssertFalse(audioPlayer.isPlaying, "Audio player should not be playing")
    }

    func testSeek() {
        audioPlayer.loadAudio(from: testAudioURL)
        let seekTime: TimeInterval = 1.0
        
        // Wait for audio to load to ensure duration is available
        let expectation = self.expectation(description: "Wait for audio to load")
        var cancellable: Any?
        cancellable = audioPlayer.$isLoaded.sink { isLoaded in
            if isLoaded {
                expectation.fulfill()
                cancellable?.cancel()
            }
        }
        waitForExpectations(timeout: 2.0)

        // Ensure the seek time is within the duration of the test audio file
        if audioPlayer.duration > seekTime {
            audioPlayer.seek(to: seekTime)
            
            // Seeking can be async, so we wait a moment for it to settle.
            let seekExpectation = self.expectation(description: "Wait for seek to complete")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                seekExpectation.fulfill()
            }
            wait(for: [seekExpectation], timeout: 1.0)
            
            XCTAssertEqual(audioPlayer.currentTime, seekTime, accuracy: 0.1, "Current time should be close to the seek time")
        } else {
            XCTFail("Test audio file is too short for this seek test. Duration: \(audioPlayer.duration)")
        }
    }
}