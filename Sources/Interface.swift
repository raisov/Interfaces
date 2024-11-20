//  Interface.swift
//  Interfaces2
//
import Darwin.net

public protocol Interface {
    ///
    var index: Int32 { get }
    
    /// BSD name of interface
    var name: String { get }
    
    
    /// Hardware (link level) address of interface;
    /// so-called MAC address for ethernet compatible interface.
    var link: [UInt8]? { get }
    
    /// True, if it is possible to work with interface as with ethernet;
    /// for example, Wi-Fi interface is ethernet compatible.
    var isEthernetCompatible: Bool { get }
    
    /// That's it, the type of interface.
    var type: InterfaceType { get }
    
    /// This interface options.
    var options: InterfaceOptions { get }
    
    /// Array of all IPv4 addresses (including aliases) of the interface.
    var ip4: [in_addr] { get }
    
    /// IPv4 network mask.
    var mask4: in_addr? { get }

    /// Array of all IPv6 addresses of the interface.
    var ip6: [in6_addr] { get }
 
    /// Array of all IPv6 network masks of the interface.
    /// - Note: The number and order of the masks correspond to the number and order
    /// of the ip6 addresses, so that they can be connected together using `zip` function.
    /// ```
    /// if let interface = (Interfaces().first{$0.ip6.count != 0}) {
    ///    let addressesWithMasks = zip(interface.ip6, interface.masks6)
    /// }
    /// ```
    var masks6: [in6_addr] { get }
    
    /// Interface broadcast address, if applicable.
    var broadcast: in_addr? { get }
}

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

public enum Interfaces {
    public static func list() -> any Sequence<any Interface> {
#if canImport(Darwin.net.route)
        RTInterfaces()
#else
        IFAInterface.listInterfaces()
#endif
    }
}
