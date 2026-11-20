import Foundation

enum WatchRangeTransition: Equatable {
  case enteredRange
  case exitedRange
}

/// Converts noisy BLE RSSI samples into stable Watch range transitions.
struct WatchRangeMonitor {
  var rssiThreshold: Int
  let staleInterval: TimeInterval

  private let outOfRangeReadingsRequired = 3
  private var consecutiveOutOfRangeReadings = 0
  private var lastReadingAt: Date?
  private(set) var isInRange = false

  init(rssiThreshold: Int = -70, staleInterval: TimeInterval = 15) {
    self.rssiThreshold = rssiThreshold
    self.staleInterval = staleInterval
  }

  mutating func record(rssi: Int, at date: Date) -> WatchRangeTransition? {
    lastReadingAt = date

    guard rssi < rssiThreshold else {
      consecutiveOutOfRangeReadings = 0
      guard !isInRange else { return nil }
      isInRange = true
      return .enteredRange
    }

    guard isInRange else { return nil }
    consecutiveOutOfRangeReadings += 1
    guard consecutiveOutOfRangeReadings >= outOfRangeReadingsRequired else { return nil }
    isInRange = false
    return .exitedRange
  }

  mutating func evaluateStaleness(at date: Date) -> WatchRangeTransition? {
    guard isInRange,
      let lastReadingAt,
      date.timeIntervalSince(lastReadingAt) >= staleInterval
    else {
      return nil
    }

    isInRange = false
    consecutiveOutOfRangeReadings = 0
    return .exitedRange
  }

  mutating func reset() {
    consecutiveOutOfRangeReadings = 0
    lastReadingAt = nil
    isInRange = false
  }
}
