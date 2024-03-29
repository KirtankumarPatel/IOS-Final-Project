//
//  Timeline.swift
//

import Foundation

/// Responsible for computing the timing metrics for the complete lifecycle of a `Request`.
public struct Timeline {
    /// The time the request was initialized.
    public let requestStartTime: CFAbsoluteTime

    /// The time the first bytes were received from or sent to the server.
    public let initialResponseTime: CFAbsoluteTime

    /// The time when the request was completed.
    public let requestCompletedTime: CFAbsoluteTime

    /// The time when the response serialization was completed.
    public let serializationCompletedTime: CFAbsoluteTime

    /// The time interval in seconds from the time the request started to the initial response from the server.
    public let latency: TimeInterval

    /// The time interval in seconds from the time the request started to the time the request completed.
    public let requestDuration: TimeInterval

    /// The time interval in seconds from the time the request completed to the time response serialization completed.
    public let serializationDuration: TimeInterval

    /// The time interval in seconds from the time the request started to the time response serialization completed.
    public let totalDuration: TimeInterval

  
    public init(
        requestStartTime: CFAbsoluteTime = 0.0,
        initialResponseTime: CFAbsoluteTime = 0.0,
        requestCompletedTime: CFAbsoluteTime = 0.0,
        serializationCompletedTime: CFAbsoluteTime = 0.0)
    {
        self.requestStartTime = requestStartTime
        self.initialResponseTime = initialResponseTime
        self.requestCompletedTime = requestCompletedTime
        self.serializationCompletedTime = serializationCompletedTime

        self.latency = initialResponseTime - requestStartTime
        self.requestDuration = requestCompletedTime - requestStartTime
        self.serializationDuration = serializationCompletedTime - requestCompletedTime
        self.totalDuration = serializationCompletedTime - requestStartTime
    }
}

// MARK: - CustomStringConvertible

extension Timeline: CustomStringConvertible {
    /// The textual representation used when written to an output stream, which includes the latency, the request
    /// duration and the total duration.
    public var description: String {
        let latency = String(format: "%.3f", self.latency)
        let requestDuration = String(format: "%.3f", self.requestDuration)
        let serializationDuration = String(format: "%.3f", self.serializationDuration)
        let totalDuration = String(format: "%.3f", self.totalDuration)

        // NOTE: Had to move to string concatenation due to memory leak filed as rdar://26761490. Once memory leak is
        // fixed, we should move back to string interpolation by reverting commit 7d4a43b1.
        let timings = [
            "\"Latency\": " + latency + " secs",
            "\"Request Duration\": " + requestDuration + " secs",
            "\"Serialization Duration\": " + serializationDuration + " secs",
            "\"Total Duration\": " + totalDuration + " secs"
        ]

        return "Timeline: { " + timings.joined(separator: ", ") + " }"
    }
}

// MARK: - CustomDebugStringConvertible

extension Timeline: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        let requestStartTime = String(format: "%.3f", self.requestStartTime)
        let initialResponseTime = String(format: "%.3f", self.initialResponseTime)
        let requestCompletedTime = String(format: "%.3f", self.requestCompletedTime)
        let serializationCompletedTime = String(format: "%.3f", self.serializationCompletedTime)
        let latency = String(format: "%.3f", self.latency)
        let requestDuration = String(format: "%.3f", self.requestDuration)
        let serializationDuration = String(format: "%.3f", self.serializationDuration)
        let totalDuration = String(format: "%.3f", self.totalDuration)

       
        let timings = [
            "\"Request Start Time\": " + requestStartTime,
            "\"Initial Response Time\": " + initialResponseTime,
            "\"Request Completed Time\": " + requestCompletedTime,
            "\"Serialization Completed Time\": " + serializationCompletedTime,
            "\"Latency\": " + latency + " secs",
            "\"Request Duration\": " + requestDuration + " secs",
            "\"Serialization Duration\": " + serializationDuration + " secs",
            "\"Total Duration\": " + totalDuration + " secs"
        ]

        return "Timeline: { " + timings.joined(separator: ", ") + " }"
    }
}
