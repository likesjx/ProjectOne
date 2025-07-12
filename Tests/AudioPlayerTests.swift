
import XCTest
import AVFoundation
@testable import ProjectOne

class AudioPlayerTests: XCTestCase {

    var audioPlayer: AudioPlayer!
    var testAudioURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        audioPlayer = AudioPlayer()

        // Create a temporary silent audio file for testing
        let temporaryDirectory = FileManager.default.temporaryDirectory
        testAudioURL = temporaryDirectory.appendingPathComponent("test.m4a")

        // If the file already exists, remove it
        if FileManager.default.fileExists(atPath: testAudioURL.path) {
            try FileManager.default.removeItem(at: testAudioURL)
        }

        // Create a silent audio file
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let assetWriter = try AVAssetWriter(outputURL: testAudioURL, fileType: .m4a)
        let assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        assetWriter.add(assetWriterInput)
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
        assetWriterInput.markAsFinished()
        assetWriter.finishWriting {
            // Finished writing
        }
    }

    override func tearDownWithError() throws {
        audioPlayer = nil
        try FileManager.default.removeItem(at: testAudioURL)
        try super.tearDownWithError()
    }

    func testLoadAudio() {
        audioPlayer.loadAudio(from: testAudioURL)
        XCTAssertNotNil(audioPlayer.isLoaded, "Audio player should have loaded the audio file")
        XCTAssertEqual(audioPlayer.currentURL, testAudioURL, "The current URL should be the test audio URL")
        XCTAssertGreaterThan(audioPlayer.duration, 0, "The duration should be greater than 0")
    }

    func testPlay() {
        audioPlayer.loadAudio(from: testAudioURL)
        audioPlayer.play()
        XCTAssertTrue(audioPlayer.isPlaying, "Audio player should be playing")
    }

    func testPause() {
        audioPlayer.loadAudio(from: testAudioURL)
        audioPlayer.play()
        audioPlayer.pause()
        XCTAssertFalse(audioPlayer.isPlaying, "Audio player should not be playing")
    }

    func testStop() {
        audioPlayer.loadAudio(from: testAudioURL)
        audioPlayer.play()
        audioPlayer.stop()
        XCTAssertFalse(audioPlayer.isPlaying, "Audio player should not be playing")
        XCTAssertEqual(audioPlayer.currentTime, 0, "Current time should be reset to 0")
    }

    func testTogglePlayback() {
        audioPlayer.loadAudio(from: testAudioURL)
        
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
        // Ensure the seek time is within the duration of the test audio file
        if audioPlayer.duration > seekTime {
            audioPlayer.seek(to: seekTime)
            XCTAssertEqual(audioPlayer.currentTime, seekTime, "Current time should be equal to the seek time")
        } else {
            XCTFail("Test audio file is too short for this seek test.")
        }
    }
}
