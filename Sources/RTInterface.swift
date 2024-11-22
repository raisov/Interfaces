//
//  RTInterface.swift
//  Interface2
import Sockets
import Foundation
#if canImport(Darwin.net.route)
import Darwin.net.route

/// A type describing network interface
public struct RTInterface: Interface {
    
    private func withHeaderPointer<R>(_ body: (UnsafePointer<if_msghdr>) -> R) -> R {
        interfaceMessages.withUnsafeBytes {
            let p = $0.baseAddress!.assumingMemoryBound(to: if_msghdr.self)
            return body(p)
        }
    }

    /// Contains routing messages with information about network interface
    private let interfaceMessages: Data

    /// Creates `Interface` as an element of `Interfaces` collection.
    /// - parameter interfaceMessages: part of the `sysctl` buffer with
    ///   information about the interface being created.
    public init(_ interfaceMessages: Data) {
        interfaceMessages.withUnsafeBytes {
            let ifm_p = $0.baseAddress!.assumingMemoryBound(to: if_msghdr.self)
            assert(ifm_p.pointee.ifm_version == RTM_VERSION)
            assert(ifm_p.pointee.ifm_type == RTM_IFINFO)
            assert(ifm_p.pointee.ifm_addrs & RTA_IFP != 0)
            assert(ifm_p.pointee.ifm_index != 0)
            ifm_p.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                assert($0.pointee.isWellFormed)
                assert($0.index == ifm_p.pointee.ifm_index)
            }
        }
        self.interfaceMessages = interfaceMessages
    }

    ///
    public var index: Int32 {
        withHeaderPointer {
            numericCast($0.pointee.ifm_index)
        }
    }

    /// BSD name of interface
    public var name: String {
        withHeaderPointer {
            $0.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                $0.name
            }
        }
    }

    /// Hardware (link level) address of interface;
    /// for ethernet - so-called MAC address.
    public var link: [UInt8]? {
        withHeaderPointer {
            $0.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                guard $0.address.count != 0 else {return nil}
                return $0.address
            }
        }
    }

    /// True, if it is possible to work with interface as with ethernet;
    /// for example, Wi-Fi interface is ethernet compatible.
    public var isEthernetCompatible: Bool {
        withHeaderPointer {
            $0.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                $0.type == IFT_ETHER
            }
        }
    }


    /// That's it, the type of interface.
    public var type: InterfaceType {
        withHeaderPointer {
            InterfaceType(Int32($0.pointee.ifm_data.ifi_type))
        }
    }
    

    /// This interface options.
    public var options: InterfaceOptions {
        withHeaderPointer {
            InterfaceOptions(rawValue: $0.pointee.ifm_flags)
        }
    }

    /// Maximum Transmission Unit size for interface.
    public var mtu: Int {
        withHeaderPointer {
            Int($0.pointee.ifm_data.ifi_mtu)
        }
    }

    /// Network routing metric.
    public var metric: Int {
        withHeaderPointer {
            Int($0.pointee.ifm_data.ifi_metric)
        }
    }

    /// Possible link speed; may be 0 if undefined.
    public var baudrate: Int {
        withHeaderPointer {
            Int($0.pointee.ifm_data.ifi_baudrate)
        }
    }

    /// This is a curried function intended to produce a function
    /// for retrieving data of given `kind` from the memory buffer
    /// containing `RTM_NEWADDR` type routing messages.
    /// - Parameters:
    ///     - kind: specifies the kind of data to extract. Possible values:
    ///        - RTAX_IFA - IP or IPv6 address of the interface
    ///        - RTAX_NETMASK - network mask for the interface
    ///        - RTAX_BRD - broadcast address of the interface (or destination address for P2P interface)
    ///     - count: size of the memory buffer
    /// - returns: specified function suitable for using as an argument for `withUnsafeBytes`
    /// - Warning: Don't try to undestand this function. It's dangerous for your peace of mind!
    private func addressExtractor(of kind: Int32, _ count: Int) ->
        (_ start: UnsafePointer<Int8>) -> [IPAddress] {

            func sa_rlen<T>(_ x: T) -> Int where T: BinaryInteger {
                return Int(x == 0 ? 4 : (x + 3) & ~3)
            }

            assert(0 <= kind && kind < RTAX_MAX)
            let bitmask = Int32(1 << kind)
            return {(_ start: UnsafePointer<Int8>) -> [IPAddress] in
                let (index, length) = start.withMemoryRebound(to: if_msghdr.self, capacity: 1) {($0.pointee.ifm_index, $0.pointee.ifm_msglen)}
                var addresses = [IPAddress]()
                var location = Int(length)
                while location != count {
                    let rtm_p = start.advanced(by: location)
                    let (version, type, length) = rtm_p.withMemoryRebound(to: rt_msghdr.self, capacity: 1) {
                        ($0.pointee.rtm_version, $0.pointee.rtm_type, $0.pointee.rtm_msglen)
                    }
                    guard version == RTM_VERSION else {
                        location += Int(length)
                        continue
                    }
                    if type == RTM_IFINFO {break}
                    guard type == RTM_NEWADDR else {
                        location += Int(length)
                        continue
                    }
                    let ip = rtm_p.withMemoryRebound(to: ifa_msghdr.self, capacity: 1) {(ifam_p) -> IPAddress? in
                        guard ifam_p.pointee.ifam_index == index else {return nil}
                        var addrs = ifam_p.pointee.ifam_addrs
                        guard addrs & bitmask == bitmask else {return nil} // there is no address here
                        var p = UnsafeRawPointer(ifam_p.advanced(by: 1))
                        for _ in 0..<kind {
                            if addrs & 1 != 0 {
                                p += sa_rlen(p.bindMemory(to: sockaddr.self, capacity: 1).pointee.sa_len)
                            }
                            addrs >>= 1
                        }
                        let sa_p = p.bindMemory(to: sockaddr.self, capacity: 1)

                        // Many, many years ago,
                        // one programmer from Berkeley
                        // decided to save a few bytes.
                        // So now I had do the following ...
                        if sa_p.pointee.sa_family == AF_INET && bitmask == RTA_NETMASK  {
                            //                       When IPv6 was invented,
                            //                       bytes have already become cheaper
                            var sin = sockaddr_in()
                            return withUnsafeMutablePointer(to: &sin) {
                                let rp = UnsafeMutableRawPointer($0)
                                rp.copyMemory(from: p, byteCount: Int(sa_p.pointee.sa_len))
                                rp.assumingMemoryBound(to: sockaddr_in.self).pointee.sin_len = numericCast(MemoryLayout<sockaddr_in>.size)
                                return rp.assumingMemoryBound(to: sockaddr_in.self).pointee.ip
                            }
                        } else {
                            if let address = sa_p.internetAddress {
                                if address.isWellFormed {
                                    return address.ip
                                }
                            }
                        }
                        // I dislike this `continue`, `break` and `return` from the middle of the loop, too.
                        // But what should I do with all these `withMemoryRebound`?
                        return nil
                    }
                    if let ip = ip {addresses.append(ip)}
                    location += Int(length)
                }
                return addresses
            }

    }

    /// Array of all IPv4 and IPv6 addresses of the interface.
    public var addresses: [IPAddress] {
        interfaceMessages.withUnsafeBytes {
            let p = $0.baseAddress!.assumingMemoryBound(to: Int8.self)
            return addressExtractor(of: RTAX_IFA, interfaceMessages.count)(p)
        }
    }
    
    /// Array of all IPv4 addresses (including aliases) of the interface.
    public var ip4: [in_addr] {
        interfaceMessages.withUnsafeBytes {
            let p = $0.baseAddress!.assumingMemoryBound(to: Int8.self)
            return addressExtractor(of: RTAX_IFA, interfaceMessages.count)(p)
                .filter{Swift.type(of: $0).family == .ip4}.compactMap{$0 as? in_addr}
        }
    }
    
    /// IPv4 network mask.
    public var mask4: in_addr? {
        interfaceMessages.withUnsafeBytes {
            let p = $0.baseAddress!.assumingMemoryBound(to: Int8.self)
            return addressExtractor(of: RTAX_NETMASK, interfaceMessages.count)(p)
                .filter{Swift.type(of: $0).family == .ip4}.first as? in_addr
        }
    }


    /// Array of all IPv6 addresses of the interface.
    public var ip6: [in6_addr] {
        interfaceMessages.withUnsafeBytes {
            let p = $0.baseAddress!.assumingMemoryBound(to: Int8.self)
            return addressExtractor(of: RTAX_IFA, interfaceMessages.count)(p)
                .filter{Swift.type(of: $0).family == .ip6}.compactMap{$0 as? in6_addr}
        }
    }

    /// Array of all IPv6 network masks of the interface.
    /// - Note: The number and order of the masks correspond to the number and order
    /// of the ip6 addresses, so that they can be connected together using `zip` function.
    /// ```
    /// if let interface = (Interfaces().first{$0.ip6.count != 0}) {
    ///    let addressesWithMasks = zip(interface.ip6, interface.masks6)
    /// }
    /// ```
    public var masks6: [in6_addr] {
        interfaceMessages.withUnsafeBytes {
            let p = $0.baseAddress!.assumingMemoryBound(to: Int8.self)
            return addressExtractor(of: RTAX_NETMASK, interfaceMessages.count)(p)
                .filter{Swift.type(of: $0).family == .ip6}.compactMap{$0 as? in6_addr}
        }
    }


    /// Interface broadcast address, if applicable.
    public var broadcast: in_addr? {
        guard self.options.contains(.broadcast) else {return nil}
        guard !self.options.contains(.pointopoint) else {return nil}
        return interfaceMessages.withUnsafeBytes {
            let p = $0.baseAddress!.assumingMemoryBound(to: Int8.self)
            return addressExtractor(of: RTAX_BRD, interfaceMessages.count)(p)
                .first{Swift.type(of: $0).family == .ip4} as? in_addr
        }
    }

    /// For point-to-point interfaces, destination address.
    public var destination: IPAddress? {
        guard self.options.contains(.pointopoint) else {return nil}
        return interfaceMessages.withUnsafeBytes {
            let p = $0.baseAddress!.assumingMemoryBound(to: Int8.self)
            return addressExtractor(of: RTAX_BRD, interfaceMessages.count)(p).first
        }
    }
}

public struct RTInterfaces: Collection {
    public typealias Element = Interface

    /// Contains `sysctl` results
    let routingMessages: Data

    public init() {
        var needed: size_t = 0
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST, 0]
        
        guard sysctl(&mib[0], 6, nil, &needed, nil, 0) == 0 else {
            fatalError(String(validatingCString: strerror(errno)) ?? "")
        }
        let buf_p = UnsafeMutableRawPointer.allocate(
            byteCount: needed,
            alignment: MemoryLayout<rt_msghdr>.alignment
        )
        
        guard sysctl(&mib[0], 6, buf_p, &needed, nil, 0) == 0 else {
            fatalError(String(validatingCString: strerror(errno)) ?? "")
        }
        // Wrap sysctl's results with `Data` for memory management
        self.routingMessages = Data(
            bytesNoCopy: buf_p,
            count: needed,
            deallocator: .custom { buf_p, _ in buf_p.deallocate() }
        )
    }
    
/// The following are necessary to ensure conformance `Collection` protocol.

    public struct Index: Comparable {
        fileprivate let value: Int
        public static func == (lhs: Index, rhs: Index) -> Bool {return lhs.value == rhs.value}
        public static func < (lhs: Index, rhs: Index) -> Bool {return lhs.value < rhs.value}
        fileprivate init(_ value: Int) {self.value = value}
    }

    private func nextIndex(from indexValue: Int) -> Index {
        routingMessages.withUnsafeBytes {
            let start = $0.baseAddress!.assumingMemoryBound(to: Int8.self)
            var location = indexValue
            while location != endIndex.value {
                let (version, type, length) = start.advanced(by: location).withMemoryRebound(to: rt_msghdr.self, capacity: 1) {
                    return ($0.pointee.rtm_version, $0.pointee.rtm_type, $0.pointee.rtm_msglen)
                }
                assert(location + Int(length) <= endIndex.value)
                guard numericCast(version) == RTM_VERSION && numericCast(type) == RTM_IFINFO  else {
                    location += Int(length)
                    continue
                }
                let (addrs, index) = start.advanced(by: location).withMemoryRebound(to: if_msghdr.self, capacity: 1) {
                    return ($0.pointee.ifm_addrs, $0.pointee.ifm_index)
                }
                guard addrs & RTA_IFP != 0 && index != 0 else {
                    location += Int(length)
                    continue
                }
                break
            }
            return Index(location)
        }
    }

    public var endIndex: Index {return Index(routingMessages.endIndex)}
    public var startIndex: Index {return nextIndex(from: routingMessages.startIndex)}

    public func index(after given: Index) -> Index {
        return routingMessages.suffix(from: given.value).withUnsafeBytes {
            let ifm_p = $0.baseAddress!.assumingMemoryBound(to: if_msghdr.self)
            assert(ifm_p.pointee.ifm_version == RTM_VERSION)
            assert(ifm_p.pointee.ifm_type == RTM_IFINFO)
            assert(ifm_p.pointee.ifm_addrs & RTA_IFP != 0)
            assert(ifm_p.pointee.ifm_index != 0)
            ifm_p.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                assert($0.pointee.isWellFormed)
                assert($0.index == ifm_p.pointee.ifm_index)
            }
            return nextIndex(from: given.value + Int(ifm_p.pointee.ifm_msglen))
        }
    }

    public subscript(position: Index) -> Element {
        return RTInterface(routingMessages.subdata(in: position.value..<index(after: position).value))
    }
}
#endif
