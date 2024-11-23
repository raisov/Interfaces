//  InterfaceType.swift
//  Interfaces package
//  Copyright (c) 2018 Vladimir Raisov
//  Licensed under MIT License
import Darwin.net

/// List of basic interface types.
public enum InterfaceType: Equatable {
    /// Possible tunnel interface
    case other
    /// Loopback interface.
    case loopback
    /// Ethernet interface.
    case ethernet
    /// generic tunnel interface; see man 4 gif.
    case gif
    /// 6to4 tunnel interface; see man 4 stf.
    case stf
    /// Layer 2 Virtual LAN using 802.1Q.
    case vlan
    /// IEEE802.3ad Link Aggregate.
    case linkAggregate
    /// IEEE1394 High Performance SerialBus.
    case fireware
    /// Transparent bridge interface.
    case bridge
    /// Value is a raw interface type code;
    /// for possible values see net/if_types.h
    case unknown(Int32)

    public init(_ code: Int32) {
        switch code {
        case IFT_OTHER: self = .other
        case IFT_LOOP: self = .loopback
        case IFT_ETHER: self = .ethernet
        case IFT_GIF: self = .gif
        case IFT_STF: self = .stf
        case IFT_L2VLAN: self = .vlan
        case IFT_IEEE8023ADLAG: self = .linkAggregate
        case IFT_IEEE1394: self = .fireware
        case IFT_BRIDGE: self = .bridge
        default: self = .unknown(code)
        }
    }

    /// Raw interface type code, espcially useful in `.other` case.
    public var code: Int32 {
        switch self {
        case .other : return IFT_OTHER
        case .loopback: return IFT_LOOP
        case .ethernet: return IFT_ETHER
        case .gif: return IFT_GIF
        case .stf: return IFT_STF
        case .vlan: return IFT_L2VLAN
        case .linkAggregate: return IFT_IEEE8023ADLAG
        case .fireware: return IFT_IEEE1394
        case .bridge: return IFT_BRIDGE
        /// For other possible values, see net/if_types.h for possible values.
        case .unknown(let _code): return _code
        }
    }

    public static func ==(lhs: InterfaceType, rhs: InterfaceType) -> Bool {
        return lhs.code == rhs.code
    }
}
