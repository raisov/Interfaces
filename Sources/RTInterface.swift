//  RTInterface.swift
//  Interfaces package
//  Copyright (c) 2018 Vladimir Raisov
//  Licensed under MIT License
import Sockets
import Foundation
#if canImport(Darwin.net.route)
import Darwin.net.route

public struct RTInterface: Interface {
    
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
                assert($0.pointee.family == sockaddr_dl.family)
                assert($0.pointee.sdl_len >= sockaddr_dl.size)
                assert($0.index == ifm_p.pointee.ifm_index)
            }
        }
        self.interfaceMessages = interfaceMessages
    }
    
    // MARK: - Implementation of `Interface` protocol properties
    
    public var index: Int32 {
        withHeaderPointer {
            numericCast($0.pointee.ifm_index)
        }
    }
    
    public var name: String {
        withHeaderPointer {
            $0.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                $0.name
            }
        }
    }
    
    public var link: [UInt8] {
        withHeaderPointer {
            $0.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                $0.address
            }
        }
    }
    
    public var isEthernetCompatible: Bool {
        withHeaderPointer {
            $0.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                $0.type == IFT_ETHER
            }
        }
    }    
    
    public var type: InterfaceType {
        withHeaderPointer {
            InterfaceType(Int32($0.pointee.ifm_data.ifi_type))
        }
    }
        
    public var options: InterfaceOptions {
        withHeaderPointer {
            InterfaceOptions(rawValue: $0.pointee.ifm_flags)
        }
    }
    public var mtu: UInt32 {
        withHeaderPointer {
            $0.pointee.ifm_data.ifi_mtu
        }
    }
    
    public var metric: UInt32 {
        withHeaderPointer {
            $0.pointee.ifm_data.ifi_metric
        }
    }
    
    public var baudrate: UInt32 {
        withHeaderPointer {
            $0.pointee.ifm_data.ifi_baudrate
        }
    }
    
    public var ip4: [in_addr] {
        getIP4Addresses(of: RTAX_IFA)
    }
    
    public var mask4: in_addr? {
        getIP4Addresses(of: RTAX_NETMASK).first
    }
    
    public var ip6: [in6_addr] {
        getIP6Addresses(of: RTAX_IFA)
    }
    
    public var masks6: [in6_addr] {
        getIP6Addresses(of: RTAX_NETMASK)
    }
    
    public var broadcast: in_addr? {
        guard self.options.contains(.broadcast) else {return nil}
        guard !self.options.contains(.pointopoint) else {return nil}
        return getIP4Addresses(of: RTAX_BRD).first
    }
    
    public var destination4: in_addr? {
        guard self.options.contains(.pointopoint) else {return nil}
        return getIP4Addresses(of: RTAX_BRD).first
    }
    
    public var destination6: in6_addr? {
        guard self.options.contains(.pointopoint) else {return nil}
        return getIP6Addresses(of: RTAX_BRD).first
    }

    // MARK: - Private methods
    
    private func withHeaderPointer<R>(_ body: (UnsafePointer<if_msghdr>) -> R) -> R {
        interfaceMessages.withUnsafeBytes {
            let p = $0.baseAddress!.assumingMemoryBound(to: if_msghdr.self)
            return body(p)
        }
    }
    
    private func getAddresses(of kind: Int32) -> [sockaddr_storage] {
        interfaceMessages.withUnsafeBytes {
            let p = $0.baseAddress!.assumingMemoryBound(to: Int8.self)
            return addressExtractor(kind, interfaceMessages.count)(p)
        }
    }
    
    private func getIP4Addresses(of kind: Int32) -> [in_addr] {
        getAddresses(of: kind).compactMap { $0.sin?.sin_addr }
    }
    
    private func getIP6Addresses(of kind: Int32) -> [in6_addr] {
        getAddresses(of: kind).compactMap {
            guard var ip6 = $0.sin6?.sin6_addr else { return nil }
            if ip6.isLinkLocal {
                ip6.__u6_addr.__u6_addr32.0 &= 0x80fe
                ip6.__u6_addr.__u6_addr32.1 = 0
            }
            return ip6
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
    private func addressExtractor(_ kind: Int32, _ count: Int) ->
    (_ start: UnsafePointer<Int8>) -> [sockaddr_storage] {
        
        func sa_rlen<T>(_ x: T) -> Int where T: BinaryInteger {
            return Int(x == 0 ? 4 : (x + 3) & ~3)
        }
        
        assert(0 <= kind && kind < RTAX_MAX)
        let bitmask = Int32(1 << kind)
        return {(_ start: UnsafePointer<Int8>) -> [sockaddr_storage] in
            let (index, length) = start.withMemoryRebound(to: if_msghdr.self, capacity: 1) {($0.pointee.ifm_index, $0.pointee.ifm_msglen)}
            var addresses = [sockaddr_storage]()
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
                let address = rtm_p.withMemoryRebound(to: ifa_msghdr.self, capacity: 1) {(ifam_p) -> sockaddr_storage? in
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
                    assert(sa_p.pointee.sa_len <= SOCK_MAXADDRLEN, "malformed sockaddr")
                    guard sa_p.pointee.sa_len <= SOCK_MAXADDRLEN else { return nil }
                    guard sa_p.pointee.sa_len > MemoryLayout<sockaddr>.offset(of: \.sa_data)! else { return nil }
                    var ss = sockaddr_storage()
                    withUnsafeMutablePointer(to: &ss) {
                        let ss_p = UnsafeMutableRawPointer($0)
                        ss_p.copyMemory(from: sa_p, byteCount: min(Int(sa_p.pointee.sa_len), Int(SOCK_MAXADDRLEN)))
                        return ss_p.assumingMemoryBound(to: sockaddr_storage.self).pointee
                    }
                    return ss
                }
                if let address {addresses.append(address)}
                location += Int(length)
            }
            return addresses
        }
        
    }
}

public struct RTInterfaces: Collection {
    public typealias Element = Interface

    /// Contains `RTM_NEWADDR` type routing messages from `sysctl` results
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
                assert($0.pointee.family == sockaddr_dl.family)
                assert($0.pointee.sdl_len >= MemoryLayout<sockaddr_dl>.size)
                assert($0.index == ifm_p.pointee.ifm_index)
            }
            return nextIndex(from: given.value + Int(ifm_p.pointee.ifm_msglen))
        }
    }

    public subscript(position: Index) -> Element {
        return RTInterface(routingMessages.subdata(in: position.value..<index(after: position).value))
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
}
#endif
