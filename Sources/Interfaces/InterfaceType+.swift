//  InterfaceType+.swift
//  Interfaces
//
import InterfaceType

extension InterfaceType: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .other: "other"
        case .loopback: "Loopback"
        case .ethernet: "Ethernet compatible"
        case .gif: "gif (generic tunnel)"
        case .stf: "stf (6to4 tunnel)"
        case .vlan: "Layer 2 VLAN using 802.1Q"
        case .linkAggregate: "IEEE802.3ad Link Aggregate"
        case .fireware: "Firewire (IEEE1394)"
        case .bridge: "Transparent bridge"
        case .cellular: "Cellular"
        default: "Interface type \(self.rawValue)"
        }
    }
}
