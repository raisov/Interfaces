//  InterfaceType.h
//  Interfaces

#ifndef InterfaceType_h
#define InterfaceType_h

#include <sys/sockio.h>
#include <net/if_types.h>

/// List of basic interface types.
typedef enum __attribute__((enum_extensibility(open))) : u_int32_t {
    /// Possible tunnel interface
    other = IFT_OTHER,
    /// Loopback interface.
    loopback = IFT_LOOP,
    /// Ethernet compatible interface. This value is rarely useful because many interfaces ‘look like’ Ethernet
    ethernet = IFT_ETHER,
    /// generic tunnel interface; see man 4 gif.
    gif = IFT_GIF,
    /// 6to4 tunnel interface; see man 4 stf.
    stf = IFT_STF,
    /// Layer 2 Virtual LAN using 802.1Q.
    vlan = IFT_L2VLAN,
    /// IEEE802.3ad Link Aggregate.
    linkAggregate = IFT_IEEE8023ADLAG,
    /// IEEE1394 High Performance SerialBus.
    fireware = IFT_IEEE1394,
    /// Transparent bridge interface.
    bridge = IFT_BRIDGE,
} InterfaceType;

#endif /* InterfaceType_h */
