//
//  TimeManager.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import CoreMedia

/// Utility for time formatting and calculation.
enum TimeManager {

    /// Converts seconds to timecode string (e.g., "00:00" or "00:00:00").
    /// - Parameter seconds: The time in seconds.
    /// - Returns: Formatted timecode string.
    static func timecodeString(from seconds: TimeInterval) -> String {
        guard seconds.isFinite else {
            return "00:00"
        }
        let time = Int(floor(seconds))

        let hours = time / 3600
        let minutes = time / 60 - hours * 60
        let secs = time % 60
        return hours == 0
            ? String(format: "%02d:%02d", minutes, secs)
            : String(format: "%02d:%02d:%02d", hours, minutes, secs)
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

/// Time jump direction with seconds.
enum JumpTimeType {
    case forward(Double)
    case backward(Double)
}

/// Playback speed options.
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
