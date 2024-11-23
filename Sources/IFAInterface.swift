//  IFAInterface.swift
//  Interfaces
//
import Darwin.net
import Sockets

public struct IFAInterface: Interface {
    public var index: Int32
    
    public var name: String
    
    public var link: [UInt8]
    
    public var isEthernetCompatible: Bool
    
    public var type: InterfaceType
    
    public var options: InterfaceOptions
    
    public var mtu: UInt32
    
    public var metric: UInt32
    
    public var baudrate: UInt32

    public var ip4: [in_addr]
    
    public var mask4: in_addr?
    
    public var ip6: [in6_addr]
    
    public var masks6: [in6_addr]
    
    public var broadcast: in_addr? {
        guard options.contains(.broadcast) else { return nil }
        guard !options.contains(.pointopoint) else { return nil }
        return dst4
    }
    
    public var destination4: in_addr? {
        guard options.contains(.pointopoint) else { return nil }
        return dst4
    }
    
    public var destination6: in6_addr? {
        guard options.contains(.pointopoint) else { return nil }
        return dst6
    }

    private var dst4: in_addr?
    
    private var dst6: in6_addr?
}

extension IFAInterface {
    static func listInterfaces() -> any Sequence<any Interface> {
        var addrList: UnsafeMutablePointer<ifaddrs>?
        defer { freeifaddrs(addrList) }
        guard getifaddrs(&addrList) == 0 else { return [] }
        let addresses = sequence(
            first: addrList,
            next: { $0.map(\.pointee.ifa_next) }
        ).compactMap(\.?.pointee)
        var types = [String: UInt8]()
        var links = [String: [UInt8]]()
        var flags = [String: Int32]()
        var mtu = [String: UInt32]()
        var metric = [String: UInt32]()
        var baudrate = [String: UInt32]()
        var ip4 = [String: [in_addr]]()
        var mask4 = [String: in_addr]()
        var ip6 = [String: [in6_addr]]()
        var masks6 = [String: [in6_addr]]()
        var dst4 = [String: in_addr]()
        var dst6 = [String: in6_addr]()

        
        
        for address in addresses {
            let name = String(cString: address.ifa_name)
            flags[name, default: 0] |= Int32(bitPattern: address.ifa_flags)
        
            if let mask_p = address.ifa_netmask {
                switch Int32(mask_p.pointee.sa_family) {
                case AF_INET:
                    if let mask = mask_p.in?.sin_addr {
                        mask4[name] = mask
                    }
                case AF_INET6:
                    if let mask = mask_p.in6?.sin6_addr {
                        masks6[name, default: []].append(mask)
                    }
                default:
                    break
                }
            }
            
            if let dst_p = address.ifa_dstaddr {
                switch Int32(dst_p.pointee.sa_family) {
                case AF_INET:
                    if let addr = dst_p.in?.sin_addr {
                        dst4[name] = addr
                    }
                case AF_INET6:
                    if let addr = dst_p.in6?.sin6_addr {
                        dst6[name] = addr
                    }
                default:
                    break
                }
            }
            
            if let addr_p = address.ifa_addr {
                switch Int32(addr_p.pointee.sa_family) {
                case AF_INET:
                    if let addr = addr_p.in?.sin_addr {
                        ip4[name, default: []].append(addr)
                    }
                case AF_INET6:
                    if let addr = addr_p.in6?.sin6_addr {
                        ip6[name, default: []].append(addr)
                    }
                case AF_LINK:
                    if let data_p = address.ifa_data?.assumingMemoryBound(to: if_data.self) {
                        types[name] = data_p.pointee.ifi_type
                        mtu[name] = data_p.pointee.ifi_mtu
                        metric[name] = data_p.pointee.ifi_metric
                        baudrate[name] = data_p.pointee.ifi_baudrate
                        if addr_p.dl != nil {
                            addr_p.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                                links[name] = $0.address
                            }
                        }
                        data_p.pointee.ifi_baudrate
                    }
                default:
                    break
                }
            }
        }
        
        return zip(types.keys, types.values).map {
            let name = $0
            let type = $1
            return IFAInterface(
                index: Int32(bitPattern: if_nametoindex(name.cString(using: .ascii))),
                name: name,
                link: links[name, default: []],
                isEthernetCompatible: true,
                type: InterfaceType(Int32(type)),
                options: InterfaceOptions(rawValue: flags[name, default: 0]),
                mtu: mtu[name, default: 0],
                metric: metric[name, default: 0],
                baudrate: baudrate[name, default: 0],
                ip4: ip4[name, default: []],
                mask4: mask4[name],
                ip6: ip6[name, default: []],
                masks6: masks6[name, default: []],
                dst4: dst4[name],
                dst6: dst6[name]
            )
        }
    }
}
