//  RTInterface.swift
//  Interfaces
//  Created in 2018 by Vladimir Raisov
//  Last modified 2024-12-07
//
import Sockets
#if canImport(Darwin.net.route)
import InterfaceType
import InterfaceFlags
import FunctionalType
import Darwin.net.route

final class RTInterface: Interface {
    
    /// Contains routing messages with information about network interface
    private let interfaceMessagePointer: UnsafePointer<if_msghdr>
    fileprivate let interfaceMessageSize: Int
    
    /// Creates `Interface` as an element of `Interfaces` collection.
    /// - parameter interfaceMessages: part of the `sysctl` buffer with
    ///   information about the interface being created.
    init?(_ pointer: UnsafeRawPointer, size: Int) {
        guard pointer.isInterfaceMessagePointer else { return nil }
        
        let buf_p = UnsafeMutableRawPointer.allocate(
            byteCount: size,
            alignment: MemoryLayout<if_msghdr>.alignment
        )
        
        buf_p.copyMemory(from: pointer, byteCount: size)
        
        interfaceMessagePointer = UnsafeRawPointer(buf_p).assumingMemoryBound(to: if_msghdr.self)
        interfaceMessageSize = size
    }
    
    deinit {
        UnsafeRawPointer(interfaceMessagePointer).deallocate()
    }
    
    // MARK: - Implementation of `Interface` protocol properties
    
    var index: Int32 {
        numericCast(interfaceMessagePointer.pointee.ifm_index)
    }
    
    var name: String {
        interfaceMessagePointer.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
            $0.name
        }
    }
    
    var link: [UInt8] {
        interfaceMessagePointer.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
            $0.address
        }
    }
    
    var isEthernetCompatible: Bool {
        interfaceMessagePointer.advanced(by: 1).withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
            $0.type == IFT_ETHER
        }
    }
    
    var type: InterfaceType? {
        InterfaceType(
            rawValue: numericCast(Int32(interfaceMessagePointer.pointee.ifm_data.ifi_type))
        )
    }
    
    var flags: InterfaceFlags {
        InterfaceFlags(rawValue: interfaceMessagePointer.pointee.ifm_flags)
    }
    
    var mtu: UInt32 {
        interfaceMessagePointer.pointee.ifm_data.ifi_mtu
    }
    
    var metric: UInt32 {
        interfaceMessagePointer.pointee.ifm_data.ifi_metric
    }
    
    var baudrate: UInt32 {
        interfaceMessagePointer.pointee.ifm_data.ifi_baudrate
    }
    
    var ip4: [in_addr] {
        getIP4Addresses(of: RTAX_IFA)
    }
    
    var mask4: in_addr? {
        getIP4Addresses(of: RTAX_NETMASK).first
    }
    
    var ip6: [in6_addr] {
        getIP6Addresses(of: RTAX_IFA)
    }
    
    var masks6: [in6_addr] {
        getIP6Addresses(of: RTAX_NETMASK)
    }
    
    var broadcast: in_addr? {
        guard self.flags.contains(.broadcast) else {return nil}
        guard !self.flags.contains(.pointopoint) else {return nil}
        return getIP4Addresses(of: RTAX_BRD).first
    }
    
    var destination4: in_addr? {
        guard self.flags.contains(.pointopoint) else {return nil}
        return getIP4Addresses(of: RTAX_BRD).first
    }
    
    var destination6: in6_addr? {
        guard self.flags.contains(.pointopoint) else {return nil}
        return getIP6Addresses(of: RTAX_BRD).first
    }
    
    // MARK: - Private methods
    
    private func getIP4Addresses(of kind: Int32) -> [in_addr] {
        addressExtractor(kind).compactMap { $0.sin?.sin_addr }
    }
    
    private func getIP6Addresses(of kind: Int32) -> [in6_addr] {
        addressExtractor(kind).compactMap {
            guard var ip6 = $0.sin6?.sin6_addr else { return nil }
            if ip6.isLinkLocal {
                ip6.__u6_addr.__u6_addr32.0 &= 0x80fe
                ip6.__u6_addr.__u6_addr32.1 = 0
            }
            return ip6
        }
    }
    
    /// This function retrieving socket addresses from a memory buffer 
    /// containing routing messages of type `RTM_NEWADDR`.
    /// - Parameters:
    ///     - kind: specifies the kind of data to extract. Possible values:
    ///        - RTAX_IFA - IP or IPv6 address of the interface
    ///        - RTAX_NETMASK - network mask for the interface
    ///        - RTAX_BRD - broadcast address of the interface (or destination address for P2P interface)
    ///     - count: size of the memory buffer
    /// - returns: array containing addressea of specified kind as `sockaddr_storage`
    /// - Warning: Don't try to undestand this function. It's dangerous for your peace of mind!
    private func addressExtractor(_ kind: Int32) ->
    [sockaddr_storage] {
        
        let start = UnsafeRawPointer(interfaceMessagePointer).assumingMemoryBound(to: Int8.self)
        let count = interfaceMessageSize
        
        func sa_rlen<T>(_ x: T) -> Int where T: BinaryInteger {
            return Int(x == 0 ? 4 : (x + 3) & ~3)
        }
        
        assert(0 <= kind && kind < RTAX_MAX)
        let bitmask = Int32(1 << kind)
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
                    ss_p.copyMemory(
                        from: sa_p,
                        byteCount: min(Int(sa_p.pointee.sa_len), Int(SOCK_MAXADDRLEN))
                    )
                }
                return ss
            }
            if let address {addresses.append(address)}
            location += Int(length)
        }
        return addresses
    }
}

/// Sequence of all network interfaces
public struct RTSequence: Sequence {
    public init() {}
    public func makeIterator() -> some IteratorProtocol<any Interface> {
        RTIterator()
    }
}

final class RTIterator: IteratorProtocol {
    private let basePointer: UnsafeRawPointer?
    private let endPointer: UnsafeRawPointer?
    private var currentPointer: UnsafeRawPointer!
    
    init() {
        var base: UnsafeMutableRawPointer?
        var end: UnsafeMutableRawPointer?
        var requiredMemory: size_t = 0
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST, 0]
        
        if sysctl(&mib[0], 6, nil, &requiredMemory, nil, 0) == 0 {
            base = UnsafeMutableRawPointer.allocate(
                byteCount: requiredMemory,
                alignment: MemoryLayout<rt_msghdr>.alignment
            )
        } else {
            assert(false, String(validatingCString: strerror(errno)) ?? "")
        }
        
        if let base, sysctl(&mib[0], 6, base, &requiredMemory, nil, 0) == 0 {
            end = base.advanced(by: requiredMemory)
            currentPointer = Self.firstInterfaceMessagePointer(from: base, to: end!)
        } else {
            assert(false, String(validatingCString: strerror(errno)) ?? "")
        }
        
        (self.basePointer, self.endPointer) = (UnsafeRawPointer(base), UnsafeRawPointer(end))
    }
    
    deinit {
        basePointer?.deallocate()
    }
    
    func next() -> (any Interface)? {
        guard let endPointer else { return nil }
         guard currentPointer != endPointer else { return nil }
            let rtm_p = currentPointer.assumingMemoryBound(to: rt_msghdr.self)
            let messageLength = Int(rtm_p.pointee.rtm_msglen)
            let next = Self.firstInterfaceMessagePointer(
                from: currentPointer.advanced(by: messageLength),
                to: endPointer
            )
        let size = next - currentPointer
        let interface = RTInterface(currentPointer, size: size)
        currentPointer = next
        return interface
    }
    
    private static func firstInterfaceMessagePointer(
        from start: UnsafeRawPointer, to end: UnsafeRawPointer
    ) -> UnsafeRawPointer {
        var pointer = start
        while pointer != end {
            let rtm_p = pointer.assumingMemoryBound(to: rt_msghdr.self)
            let messageLength = Int(rtm_p.pointee.rtm_msglen)
            assert(messageLength >= 4, "malformed routing message")
            guard messageLength >= 4 else { return end }
            let next = pointer.advanced(by: messageLength)
            assert(next <= end)
            guard next <= end else { return end }
            if pointer.isInterfaceMessagePointer {
                return pointer
            }
            pointer = next
        }
        return end
    }
}

fileprivate extension UnsafeRawPointer {
    var isInterfaceMessagePointer: Bool {
        let rtm_p = assumingMemoryBound(to: rt_msghdr.self)
        guard rtm_p.pointee.rtm_version == RTM_VERSION else { return false }
        guard rtm_p.pointee.rtm_type == RTM_IFINFO else { return false }
        
        let ifm_p = assumingMemoryBound(to: if_msghdr.self)
        guard ifm_p.pointee.ifm_addrs & RTA_IFP != 0 else { return false }
        guard ifm_p.pointee.ifm_index != 0 else { return false }
        assert(rtm_p.pointee.rtm_msglen >= MemoryLayout<if_msghdr>.size, "malformed routing message")
        guard rtm_p.pointee.rtm_msglen >= MemoryLayout<if_msghdr>.size else { return false }
        let sdl_p = UnsafeRawPointer(ifm_p.advanced(by: 1)).assumingMemoryBound(to: sockaddr_dl.self)
        guard sdl_p.pointee.family == sockaddr_dl.family else { return false }
        guard sdl_p.pointee.sdl_len >= sockaddr_dl.size else { return false }
        guard sdl_p.index == ifm_p.pointee.ifm_index else { return false }
        return true
    }
}
#endif
