//  Interface.swift
//  Interfaces
//  Created in 2018 by Vladimir Raisov
//  Last modified 2024-12-07
//
import Darwin.net
import Sockets
import InterfaceType
import InterfaceFlags
import FunctionalType

/// Network interface description
public protocol Interface {
    ///
    var index: Int32 { get }
    
    /// BSD name of interface
    var name: String { get }
    
    /// Hardware (link level) address of interface;
    /// so-called MAC address for ethernet compatible interface.
    var link: [UInt8] { get }
    
    /// That's it, the type of interface.
    var type: InterfaceType? { get }

    /// Maximum Transmission Unit size for interface.
    var mtu: UInt32 { get }

    /// Network routing metric.
    var metric: UInt32 { get }

    /// Possible link speed; may be 0 if undefined.
    var baudrate: UInt32 { get }

    /// Array of all IPv4 addresses (including aliases) of the interface.
    var ip4: [in_addr] { get }
    
    /// Array of all IPv6 addresses of the interface.
    var ip6: [in6_addr] { get }
    
    /// IPv4 network mask.
    var mask4: in_addr? { get }
    
    /// Array of all IPv6 network masks of the interface.
    /// - Note: The number and order of the masks correspond to the number and order
    /// of the ip6 addresses, so that they can be connected together using `zip` function.
    /// ```
    /// if let interface = (Interfaces().first{$0.ip6.count != 0}) {
    ///    let addressesWithMasks = zip(interface.ip6, interface.masks6)
    /// }
    /// ```
    var masks6: [in6_addr] { get }
    
    /// This interface options.
    var flags: InterfaceFlags { get }

    /// Interface broadcast address, if applicable.
    var broadcast: in_addr? { get }

    /// Destination addree for point to point interface
    var destination4: in_addr? { get }
    var destination6: in6_addr? { get }
    
}

// MARK: - Implementation

extension Interface {
    /// `masks6` represented as prefix lengths.
    public var prefixes6: [Int] {
        return self.masks6.map {
            var in6a = $0
            return withUnsafeBytes(of: &in6a) {bytes in
                var i = 0
                var n = 0
                while i != bytes.count && bytes[i] == 0xff {
                    n += 8
                    i += 1
                }
                if i != bytes.count {
                    var b = bytes[i]
                    while b != 0 {
                        b <<= 1
                        n += 1
                    }
                }
                return n
            }
        }
    }
}

// MARK: - Interfaces

#if canImport(Darwin.net.route)
public typealias Interfaces = RTSequence
#else
public typealias Interfaces = IFASequence
#endif
