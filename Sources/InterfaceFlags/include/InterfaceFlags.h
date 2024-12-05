//  InterfaceFlags.h
//  Interfaces

#ifndef InterfaceFlags_h
#define InterfaceFlags_h

#include <sys/sockio.h>
#include <net/if_types.h>

/// List of some useful interface options.
typedef enum __attribute__((flag_enum)) : int32_t {
    /// Interface is up.
    up = IFF_UP,
    /// Interface has a broadcast address.
    broadcast = IFF_BROADCAST,
    /// Loopback interface.
    loopback = IFF_LOOPBACK,
    /// Point-to-point link.
    pointopoint = IFF_POINTOPOINT,
    /// I don't know what does it mean, but ifconfig call it "SMART".
    smart = IFF_NOTRAILERS,
    /// Driver resources allocated.
    running = IFF_RUNNING,
    /// No address resolution protocol in network.
    noarp = IFF_NOARP,
    /// Interface receives all packets in connected networ.
    promisc = IFF_PROMISC,
    /// Receives all multicast packets, as a `promisc` for multicast.
    allmulti = IFF_ALLMULTI,
    /// Can't hear own transmissions.
    simplex = IFF_SIMPLEX,
    /// Uses alternate physical connection.
    altphys = IFF_ALTPHYS,
    /// Supports multicast.
    multicast = IFF_MULTICAST,
} InterfaceFlags;

#endif /* InterfaceFlags_h */
