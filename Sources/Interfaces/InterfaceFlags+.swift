//  InterfaceFlags+.swift
//  Interfaces
//
import InterfaceFlags

extension InterfaceFlags: CustomStringConvertible {
    public var description: String {
        var flags = [String]()
        if contains(.up) {flags.append("up")}
        if contains(.broadcast) {flags.append("broadcast")}
        if contains(.loopback) {flags.append("loopback")}
        if contains(.pointopoint) {flags.append("pointopoint")}
        if contains(.smart) {flags.append("smart")}
        if contains(.running) {flags.append("running")}
        if contains(.noarp) {flags.append("noarp")}
        if contains(.promisc) {flags.append("promisc")}
        if contains(.allmulti) {flags.append("allmulti")}
        if contains(.simplex) {flags.append("simplex")}
        if contains(.altphys) {flags.append("altphys")}
        if contains(.multicast) {flags.append("multicast")}
        return flags.joined(separator: ", ")
    }
}
