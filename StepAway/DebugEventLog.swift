// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import Foundation

final class DebugEventLog {
    struct Record {
        let sequence: Int
        let timestamp: Date
        let message: String
    }

    private var records: [Record] = []
    private var nextSequence = 1
    private let capacity: Int
    private let formatter: DateFormatter

    init(capacity: Int = 500) {
        self.capacity = capacity
        formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
    }

    var count: Int {
        records.count
    }

    func append(_ message: String, at timestamp: Date = Date()) {
        let record = Record(sequence: nextSequence, timestamp: timestamp, message: message)
        nextSequence += 1
        records.append(record)
        if records.count > capacity {
            records.removeFirst(records.count - capacity)
        }
    }

    func clear() {
        records.removeAll(keepingCapacity: true)
    }

    func formattedText(since interval: TimeInterval?) -> String {
        let cutoff = interval.map { Date().addingTimeInterval(-$0) }
        let filtered = records.filter { record in
            guard let cutoff else { return true }
            return record.timestamp >= cutoff
        }
        return filtered.map { record in
            "\(formatter.string(from: record.timestamp)) | seq=\(record.sequence) | \(record.message)"
        }.joined(separator: "\n")
    }
}
