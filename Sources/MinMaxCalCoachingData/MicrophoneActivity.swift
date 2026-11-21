struct MicrophoneActivity {
    // MARK: Internal

    mutating func update(_ detected: Bool, at time: Double) {
        if detected {
            start = start ?? time
        } else if let start {
            if time > start {
                completed.append(start ..< time)
            }
            self.start = nil
        }
    }

    mutating func intervals(from start: Double, to end: Double) -> [Range<Double>] {
        completed.removeAll { $0.upperBound <= start }
        var intervals = completed
        if let activeStart = self.start, end > activeStart {
            intervals.append(activeStart ..< end)
        }
        return intervals.compactMap { interval in
            let lower = max(start, interval.lowerBound)
            let upper = min(end, interval.upperBound)
            return upper > lower ? lower ..< upper : nil
        }
    }

    // MARK: Private

    private var start: Double?
    private var completed: [Range<Double>] = []
}
