//  IFAInterface.swift
//  Interfaces
//  Created in 2024 by Vladimir Raisov
//  Last modified 2024-12-07
//
import Darwin.net
import Sockets
import InterfaceType
import InterfaceFlags
import FunctionalType

public struct IFAInterface: Interface {
    public var name: String
    
    public var index: Int32 {
        Int32(bitPattern: if_nametoindex(name.cString(using: .ascii)))
    }

    public var type: InterfaceType?
    
    public var link: [UInt8]
    
    public var mtu: UInt32
    
    public var metric: UInt32
    
    public var baudrate: UInt32

    public var ip4: [in_addr]
    
    public var ip6: [in6_addr]
    
    public var mask4: in_addr?
    
    public var masks6: [in6_addr]
    
    public var flags: InterfaceFlags
    
    public var broadcast: in_addr? {
        guard flags.contains(.broadcast) else { return nil }
        guard !flags.contains(.pointopoint) else { return nil }
        return dst4
    }
    
    public var destination4: in_addr? {
        guard flags.contains(.pointopoint) else { return nil }
        return dst4
    }
    
    public var destination6: in6_addr? {
        guard flags.contains(.pointopoint) else { return nil }
        return dst6
    }
    
    fileprivate var dst4: in_addr?
    
    fileprivate var dst6: in6_addr?
    
    
}

/// Sequence of all network interfaces
public struct IFASequence: Sequence {
    public init() {}
    public func makeIterator() -> some IteratorProtocol<any Interface> {
        IFAIterator()
    }
}

final class IFAIterator: IteratorProtocol {
    private let baseAddress: UnsafeMutablePointer<ifaddrs>?
    private var currentAddress: UnsafePointer<ifaddrs>?
    
    init() {
        var addrList: UnsafeMutablePointer<ifaddrs>?
        baseAddress = getifaddrs(&addrList) == 0 ? addrList : nil
        currentAddress = UnsafePointer(baseAddress)
    }
     
    deinit {
        freeifaddrs(baseAddress)
    }
    
    func next() -> (any Interface)? {
        guard let address = currentAddress else { return nil }
        let name = String(cString: address.pointee.ifa_name)
        var type: UInt32?
        var link: [UInt8] = []
        var mtu: UInt32 = 0
        var metric: UInt32 = 0
        var baudrate: UInt32 = 0
        var ip4: [in_addr] = []
        var ip6: [in6_addr] = []
        var mask4: in_addr?
        var masks6: [in6_addr] = []
        var flags: Int32 = 0
        var dst4: in_addr?
        var dst6: in6_addr?
        while let address = currentAddress, String(cString: address.pointee.ifa_name) == name {
            if let addr_p = address.pointee.ifa_addr {
                switch Int32(addr_p.pointee.sa_family) {
                case sockaddr_in.family:
                    if let addr = addr_p.sin?.sin_addr {
                        ip4.append(addr)
                    }
                case sockaddr_in6.family:
                    if let addr = addr_p.sin6?.sin6_addr {
                        ip6.append(addr)
                    }
                case sockaddr_dl.family:
                    if let data_p = address.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                        type = numericCast(data_p.pointee.ifi_type)
                        mtu = data_p.pointee.ifi_mtu
                        metric = data_p.pointee.ifi_metric
                        baudrate = data_p.pointee.ifi_baudrate
                        addr_p.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                            if $0.pointee.sdl_len >= sockaddr_dl.size {
                                link = $0.address
                            }
                        }
                    }
                default:
                    break
                }
            }
            
            if let mask_p = address.pointee.ifa_netmask {
                switch Int32(mask_p.pointee.sa_family) {
                case AF_INET:
                    if let mask = mask_p.sin?.sin_addr {
                        mask4 = mask
                    }
                case AF_INET6:
                    if let mask = mask_p.sin6?.sin6_addr {
                        masks6.append(mask)
                    }
                default:
                    break
                }
            }
            
            flags |= Int32(bitPattern: address.pointee.ifa_flags)
            
            if let dst_p = address.pointee.ifa_dstaddr {
                switch Int32(dst_p.pointee.sa_family) {
                case AF_INET:
                    if let addr = dst_p.sin?.sin_addr {
                        dst4 = addr
                    }
                case AF_INET6:
                    if let addr = dst_p.sin6?.sin6_addr {
                        dst6 = addr
                    }
                default:
                    break
                }
            }
            currentAddress = UnsafePointer(address.pointee.ifa_next)
        }
        
        if currentAddress == nil {
            return nil
        } else {
            return IFAInterface(
                name: name,
                type: type.flatMap { InterfaceType(rawValue: $0) },
                link: link,
                mtu: mtu,
                metric: metric,
                baudrate: baudrate,
                ip4: ip4,
                ip6: ip6,
                mask4: mask4,
                masks6: masks6,
                flags: InterfaceFlags(rawValue: flags),
                dst4: dst4,
                dst6: dst6
            )
        }
    }
}
