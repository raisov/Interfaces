//  FunctionalType+.swift
//  Interfaces
//
import FunctionalType

extension FunctionalType: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown: "unknown"
        case .loopback: "loopback"
        case .wired: "wired"
        case .wifi: "WiFi"
        case .awdl: "AWDL"
        case .cellular: "cellular"
        case .intcoproc: "intcoproc"
        case .companionLink: "companion link"
        case .management: "management"
        @unknown default: "FunctionalType \(self.rawValue)"
        }
    }
}
