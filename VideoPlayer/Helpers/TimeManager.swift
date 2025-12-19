//
//  TimeManager.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import CoreMedia

struct TimeManager {

    /// Transfer seconds(Float) to 00:00:00(String).
    /// - Parameter seconds: The time will be transfered to timecode String.
    /// - Returns: Timecode String. Would be like 00:00:00.
    static func floatToTimecodeString(seconds: Float) -> String {
        guard !(seconds.isNaN || seconds.isInfinite) else {
            return "00:00"
        }
        let time = Int(floor(seconds))

        let hours = time / 3600
        let minutes = time / 60 - hours * 60
        let seconds = time % 60
        let timecodeString = hours == .zero ? String(format: "%02ld:%02ld", minutes, seconds) : String(format: "%02ld:%02ld:%02ld", hours, minutes, seconds)
        return timecodeString
    }

    /// Calculate if the time user wish to seek is valid or not.
    /// - Parameters:
    ///   - duration: The duration of current player item.
    ///   - currentTime: The currentTime of current player item.
    ///   - jumpTimeType: Jump forward/backward for 15 seconds.
    /// - Returns: The valid CMTime available to seek in current player item.
    static func getValidSeekTime(duration: CMTime,
                                 currentTime: CMTime,
                                 jumpTimeType: JumpTimeType) -> CMTime {
        let currentSeconds = CMTimeGetSeconds(currentTime)
        var seekSeconds: Float64 = .zero
        switch jumpTimeType {
        case .forward(let associateSeconds):
            seekSeconds = currentSeconds + associateSeconds
        case .backward(let associateSeconds):
            seekSeconds = currentSeconds - associateSeconds
        }
        let currentDuration = CMTimeGetSeconds(duration)
        seekSeconds = seekSeconds > currentDuration ? currentDuration : seekSeconds
        seekSeconds = seekSeconds < 0 ? 0.0 : seekSeconds
        return CMTime(seconds: seekSeconds, preferredTimescale: 1)
    }

    /// Transfer slider value on progress bar to CMTime.
    /// - Parameters:
    ///   - sliderValue: The value of progress bar.
    ///   - duration: The duration of current player item.
    /// - Returns: CMTime which represent the slider value.
    static func getCMTime(from sliderValue: Double, duration: CMTime) -> CMTime {
        let durationSeconds = CMTimeGetSeconds(duration)
        let seekTime = durationSeconds * sliderValue
        return CMTimeMake(value: Int64(ceil(seekTime)), timescale: 1)
    }
}

// MARK: - Supporting Types

enum JumpTimeType {
    case forward(Double)
    case backward(Double)
}

enum SpeedButtonType {
    case slow
    case normal
    case fast

    var speedRate: Float {
        switch self {
        case .slow: return 0.5
        case .normal: return 1.0
        case .fast: return 1.5
        }
    }
}
