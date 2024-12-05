//  FunctionalType.h
//  Interfaces

#ifndef FunctionalType_h
#define FunctionalType_h

#include <sys/sockio.h>
#include <net/if_types.h>

/// `request` argument  for ioctl function (man 2 ioctl)
/// - Note: from sys/sockio.h (Not defined for Swift)
typedef enum __attribute__((enum_extensibility(open))) : unsigned long {
    /// get interface functional type
    functionalType = SIOCGIFFUNCTIONALTYPE,
} IOCTLRequest;

typedef enum __attribute__((enum_extensibility(open))) : u_int32_t {
    unknown       = IFRTYPE_FUNCTIONAL_UNKNOWN,
    loopback    = IFRTYPE_FUNCTIONAL_LOOPBACK,
    wired         = IFRTYPE_FUNCTIONAL_WIRED,
    wifiInfra     = IFRTYPE_FUNCTIONAL_WIFI_INFRA,
    wifiAWDL      = IFRTYPE_FUNCTIONAL_WIFI_AWDL,
    cellular      = IFRTYPE_FUNCTIONAL_CELLULAR,
    intcoproc     = IFRTYPE_FUNCTIONAL_INTCOPROC,
    companionLink = IFRTYPE_FUNCTIONAL_COMPANIONLINK,
    management    = IFRTYPE_FUNCTIONAL_MANAGEMENT,
    last          = IFRTYPE_FUNCTIONAL_LAST,
} FunctionalType;

#endif /* FunctionalType_h */
