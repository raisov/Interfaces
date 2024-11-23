//  InterfaceOptions.swift
//  Interfaces package
//  Copyright (c) 2018 Vladimir Raisov
//  Licensed under MIT License
import Darwin.net

/// List of some useful interface options.
public struct InterfaceOptions: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) {self.rawValue = rawValue}
    /// Interface is up.
    public static let up = InterfaceOptions(rawValue: IFF_UP)
    /// Interface has a broadcast address.
    public static let broadcast = InterfaceOptions(rawValue: IFF_BROADCAST)
    /// Loopback interface.
    public static let loopback = InterfaceOptions(rawValue: IFF_LOOPBACK)
    /// Point-to-point link.
    public static let pointopoint = InterfaceOptions(rawValue: IFF_POINTOPOINT)
    /// I don't know what does it mean, but ifconfig call it "SMART".
    public static let smart = InterfaceOptions(rawValue: IFF_NOTRAILERS)
    /// Driver resources allocated.
    public static let running = InterfaceOptions(rawValue: IFF_RUNNING)
    /// No address resolution protocol in network.
    public static let noarp = InterfaceOptions(rawValue: IFF_NOARP)
    /// Interface receives all packets in connected networ.
    public static let promisc = InterfaceOptions(rawValue: IFF_PROMISC)
    /// Receives all multicast packets, as a `promisc` for multicast.
    public static let allmulti = InterfaceOptions(rawValue: IFF_ALLMULTI)
    /// Can't hear own transmissions.
    public static let simplex = InterfaceOptions(rawValue: IFF_SIMPLEX)
    /// Uses alternate physical connection.
    public static let altphys = InterfaceOptions(rawValue: IFF_ALTPHYS)
    /// Supports multicast.
    public static let multicast = InterfaceOptions(rawValue: IFF_MULTICAST)
}
