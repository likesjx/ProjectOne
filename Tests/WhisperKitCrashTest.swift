
import XCTest
import AVFoundation
import WhisperKit
@testable import ProjectOne

/// This test case is specifically designed to reproduce and diagnose the
/// WhisperKit MLMultiArray buffer overflow crash.
class WhisperKitCrashTest: XCTestCase {

    var silentAudioURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Create a short, silent audio file to use for the transcription test.
        silentAudioURL = try createSilentAudioFile(duration: 1.0)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: silentAudioURL)
        try super.tearDownWithError()
    }

    /// This test attempts to transcribe a silent audio file using the WhisperKitTranscriber.
    /// It is expected to crash if the buffer overflow bug is present.
    func testForWhisperKitCrash() async {
        // Using the .tiny model as it's the smallest and fastest to load.
        guard let transcriber = try? WhisperKitTranscriber(locale: Locale(identifier: "en-US"), modelSize: .tiny) else {
            XCTFail("Failed to initialize WhisperKitTranscriber")
            return
        }

        do {
            let audioData = try Data(contentsOf: silentAudioURL)
            let audioFile = try AVAudioFile(forReading: silentAudioURL)
            let audioFormat = audioFile.processingFormat
            let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(audioFile.length))!
            try audioFile.read(into: audioBuffer)

            let audioInfo = AudioData(data: audioData, buffer: audioBuffer, format: audioFormat)
            
            // This is the line that is expected to crash.
            _ = try await transcriber.transcribe(audio: audioInfo, configuration: .default)
            
            XCTFail("WhisperKit did not crash, which may indicate the bug is resolved or the test setup is incorrect.")
        } catch {
            // We expect a crash, but if it throws an error instead, we log it.
            XCTFail("WhisperKit transcription failed with an error, not a crash: \(error.localizedDescription)")
        }
    }

    // Helper function to create a silent audio file.
    private func createSilentAudioFile(duration: TimeInterval) throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let url = temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000, // WhisperKit expects 16kHz
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
            let sampleRate = 16000.0
            let totalSamples = Int(duration * sampleRate)
            let bufferSize = totalSamples * 2 // 16-bit audio

            guard let silentData = NSMutableData(length: bufferSize) else {
                XCTFail("Failed to create silent data buffer")
                expectation.fulfill()
                return
            }

            var blockBuffer: CMBlockBuffer?
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: silentData.mutableBytes,
                blockLength: bufferSize,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: bufferSize,
                flags: 0,
                blockBufferOut: &blockBuffer)

            var sampleBuffer: CMSampleBuffer?
            var asbd = AudioStreamBasicDescription(mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
            var formatDesc: CMFormatDescription?
            CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &formatDesc)

            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: Int32(sampleRate)), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
            CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: blockBuffer, formatDescription: formatDesc, sampleCount: CMSampleTimingInfo.invalid.duration.value == 0 ? 1 : CMSampleTimingInfo.invalid.duration.value, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer)

            if let finalSampleBuffer = sampleBuffer {
                writerInput.append(finalSampleBuffer)
            }
            
            writerInput.markAsFinished()
            writer.finishWriting {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
        return url
    }
}
