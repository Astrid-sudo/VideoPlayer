//
//  TimeManagerTests.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/21.
//

import Testing
import CoreMedia
@testable import VideoPlayer

struct TimeManagerTests {

    // MARK: - floatToTimecodeString Tests

    @Test func floatToTimecodeString_zeroSeconds_returnsZeroZero() {
        let result = TimeManager.floatToTimecodeString(seconds: 0)
        #expect(result == "00:00")
    }

    @Test func floatToTimecodeString_lessThanMinute_formatsCorrectly() {
        let result = TimeManager.floatToTimecodeString(seconds: 45)
        #expect(result == "00:45")
    }

    @Test func floatToTimecodeString_exactMinute_formatsCorrectly() {
        let result = TimeManager.floatToTimecodeString(seconds: 60)
        #expect(result == "01:00")
    }

    @Test func floatToTimecodeString_minutesAndSeconds_formatsCorrectly() {
        let result = TimeManager.floatToTimecodeString(seconds: 125)
        #expect(result == "02:05")
    }

    @Test func floatToTimecodeString_lessThanHour_showsMinutesAndSeconds() {
        let result = TimeManager.floatToTimecodeString(seconds: 3599)
        #expect(result == "59:59")
    }

    @Test func floatToTimecodeString_exactHour_showsHoursFormat() {
        let result = TimeManager.floatToTimecodeString(seconds: 3600)
        #expect(result == "01:00:00")
    }

    @Test func floatToTimecodeString_hoursMinutesSeconds_formatsCorrectly() {
        let result = TimeManager.floatToTimecodeString(seconds: 3661)
        #expect(result == "01:01:01")
    }

    @Test func floatToTimecodeString_multipleHours_formatsCorrectly() {
        let result = TimeManager.floatToTimecodeString(seconds: 7325)
        #expect(result == "02:02:05")
    }

    @Test func floatToTimecodeString_nan_returnsZeroZero() {
        let result = TimeManager.floatToTimecodeString(seconds: Float.nan)
        #expect(result == "00:00")
    }

    @Test func floatToTimecodeString_infinity_returnsZeroZero() {
        let result = TimeManager.floatToTimecodeString(seconds: Float.infinity)
        #expect(result == "00:00")
    }

    @Test func floatToTimecodeString_negativeInfinity_returnsZeroZero() {
        let result = TimeManager.floatToTimecodeString(seconds: -Float.infinity)
        #expect(result == "00:00")
    }

    @Test func floatToTimecodeString_floatValue_floorsToInteger() {
        let result = TimeManager.floatToTimecodeString(seconds: 65.9)
        #expect(result == "01:05")
    }

    // MARK: - getValidSeekTime Tests

    @Test func getValidSeekTime_forwardWithinBounds_addsTime() {
        let duration = CMTime(seconds: 100, preferredTimescale: 1)
        let currentTime = CMTime(seconds: 30, preferredTimescale: 1)

        let result = TimeManager.getValidSeekTime(
            duration: duration,
            currentTime: currentTime,
            jumpTimeType: .forward(15)
        )

        #expect(CMTimeGetSeconds(result) == 45)
    }

    @Test func getValidSeekTime_backwardWithinBounds_subtractsTime() {
        let duration = CMTime(seconds: 100, preferredTimescale: 1)
        let currentTime = CMTime(seconds: 30, preferredTimescale: 1)

        let result = TimeManager.getValidSeekTime(
            duration: duration,
            currentTime: currentTime,
            jumpTimeType: .backward(15)
        )

        #expect(CMTimeGetSeconds(result) == 15)
    }

    @Test func getValidSeekTime_forwardExceedsDuration_clampsToDuration() {
        let duration = CMTime(seconds: 100, preferredTimescale: 1)
        let currentTime = CMTime(seconds: 90, preferredTimescale: 1)

        let result = TimeManager.getValidSeekTime(
            duration: duration,
            currentTime: currentTime,
            jumpTimeType: .forward(15)
        )

        #expect(CMTimeGetSeconds(result) == 100)
    }

    @Test func getValidSeekTime_backwardBelowZero_clampsToZero() {
        let duration = CMTime(seconds: 100, preferredTimescale: 1)
        let currentTime = CMTime(seconds: 10, preferredTimescale: 1)

        let result = TimeManager.getValidSeekTime(
            duration: duration,
            currentTime: currentTime,
            jumpTimeType: .backward(15)
        )

        #expect(CMTimeGetSeconds(result) == 0)
    }

    @Test func getValidSeekTime_forwardFromZero_addsTime() {
        let duration = CMTime(seconds: 100, preferredTimescale: 1)
        let currentTime = CMTime(seconds: 0, preferredTimescale: 1)

        let result = TimeManager.getValidSeekTime(
            duration: duration,
            currentTime: currentTime,
            jumpTimeType: .forward(15)
        )

        #expect(CMTimeGetSeconds(result) == 15)
    }

    @Test func getValidSeekTime_backwardFromEnd_subtractsTime() {
        let duration = CMTime(seconds: 100, preferredTimescale: 1)
        let currentTime = CMTime(seconds: 100, preferredTimescale: 1)

        let result = TimeManager.getValidSeekTime(
            duration: duration,
            currentTime: currentTime,
            jumpTimeType: .backward(15)
        )

        #expect(CMTimeGetSeconds(result) == 85)
    }

    // MARK: - getCMTime Tests

    @Test func getCMTime_zeroSliderValue_returnsZero() {
        let duration = CMTime(seconds: 100, preferredTimescale: 1)

        let result = TimeManager.getCMTime(from: 0, duration: duration)

        #expect(CMTimeGetSeconds(result) == 0)
    }

    @Test func getCMTime_fullSliderValue_returnsDuration() {
        let duration = CMTime(seconds: 100, preferredTimescale: 1)

        let result = TimeManager.getCMTime(from: 1.0, duration: duration)

        #expect(CMTimeGetSeconds(result) == 100)
    }

    @Test func getCMTime_halfSliderValue_returnsHalfDuration() {
        let duration = CMTime(seconds: 100, preferredTimescale: 1)

        let result = TimeManager.getCMTime(from: 0.5, duration: duration)

        #expect(CMTimeGetSeconds(result) == 50)
    }

    @Test func getCMTime_quarterSliderValue_returnsQuarterDuration() {
        let duration = CMTime(seconds: 120, preferredTimescale: 1)

        let result = TimeManager.getCMTime(from: 0.25, duration: duration)

        #expect(CMTimeGetSeconds(result) == 30)
    }

}
