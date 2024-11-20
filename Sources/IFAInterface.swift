//
//  IFAInterface.swift
//  Interface2
//
//  Created by bp on 19.11.2024.
//


//  IFAInterface.swift
//  Interfaces
//
import Darwin.net

public struct IFAInterface {
    public var index: Int32
    
    public var name: String
    
    public var link: [UInt8]?
    
    public var isEthernetCompatible: Bool
    
    public var type: InterfaceType
    
    public var options: InterfaceOptions
    
    public var ip4: [in_addr]
    
    public var mask4: in_addr?
    
    public var dst4: in_addr?
    
    public var ip6: [in6_addr]
    
    public var masks6: [in6_addr]
    
    public var dst6: in6_addr?
    
    public var broadcast: in_addr? {
        guard options.contains(.broadcast) else { return nil }
        guard !options.contains(.pointopoint) else { return nil }
        return dst4
    }
}

extension IFAInterface: Interface {
    public static func listInterfaces() -> any Sequence<any Interface> {
        var addrList: UnsafeMutablePointer<ifaddrs>?
        defer { freeifaddrs(addrList) }
        guard getifaddrs(&addrList) == 0 else { return [] }
        let addresses = sequence(
            first: addrList,
            next: { $0.map(\.pointee.ifa_next) }
        ).compactMap(\.?.pointee)
        var types = [String: InterfaceType]()
        var links = [String: [UInt8]]()
        var flags = [String: Int32]()
        var ip4 = [String: [in_addr]]()
        var mask4 = [String: in_addr]()
        var dst4 = [String: in_addr]()
        var ip6 = [String: [in6_addr]]()
        var masks6 = [String: [in6_addr]]()
        var dst6 = [String: in6_addr]()

        
        
        for address in addresses {
            let name = String(cString: address.ifa_name)
            flags[name, default: 0] |= Int32(bitPattern: address.ifa_flags)
            
            if let mask_p = address.ifa_netmask {
                switch Int32(mask_p.pointee.sa_family) {
                case AF_INET:
                    if let in4 = mask_p.internetAddress, let addr = in4.ip as? in_addr {
                        mask4[name] = addr
                    }
                case AF_INET6:
                    if let in6 = mask_p.internetAddress, in6.isWellFormed, let addr = in6.ip as? in6_addr {
                        masks6[name, default: []].append(addr)
                    }
                default:
                    break
                }
            }
            
            if let dst_p = address.ifa_dstaddr {
                switch Int32(dst_p.pointee.sa_family) {
                case AF_INET:
                    if let in4 = dst_p.internetAddress, let addr = in4.ip as? in_addr {
                        dst4[name] = addr
                    }
                case AF_INET6:
                    if let in6 = dst_p.internetAddress, in6.isWellFormed, let addr = in6.ip as? in6_addr {
                        dst6[name] = addr
                    }
                default:
                    break
                }
            }
            
            switch Int32(address.ifa_addr.pointee.sa_family) {
            case AF_INET:
                if let in4 = address.ifa_addr.internetAddress, in4.isWellFormed, let addr = in4.ip as? in_addr {
                    ip4[name, default: []].append(addr)
                }
            case AF_INET6:
                if let in6 = address.ifa_addr.internetAddress, in6.isWellFormed, let addr = in6.ip as? in6_addr {
                    ip6[name, default: []].append(addr)
                }
            case AF_LINK:
                if let data_p = address.ifa_data {
                    let type = InterfaceType(Int32(data_p.assumingMemoryBound(to: if_data.self).pointee.ifi_type))
                    types[name] = type
                    if type == .ethernet {
                        address.ifa_addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
                            if $0.pointee.isWellFormed {
                                links[name] = $0.address
                            }
                        }
                    }
                }
                if let in6 = address.ifa_addr.internetAddress, in6.isWellFormed, let addr = in6.ip as? in6_addr {
                    ip6[name, default: []].append(addr)
                }
            default:
                break
            }
        }
        
        return zip(types.keys, types.values).map {
            let name = $0
            let type = $1
            return IFAInterface(
                index: Int32(bitPattern: if_nametoindex(name.cString(using: .ascii))),
                name: name,
                link: links[name],
                isEthernetCompatible: true,
                type: type,
                options: InterfaceOptions(rawValue: flags[name, default: 0]),
                ip4: ip4[name, default: []],
                mask4: mask4[name],
                dst4: dst4[name],
                ip6: ip6[name, default: []],
                masks6: masks6[name, default: []],
                dst6: dst6[name]
            )
        }
    }
}
