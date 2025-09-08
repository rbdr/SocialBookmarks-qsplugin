//
//  SocialSite.m
//  QSDeliciousPlugIn
//

#import "SocialSite.h"

@implementation SocialSiteHelper

+ (NSString *)displayNameForSite:(SocialSite)site {
    switch (site) {
        case SocialSiteDelicious:
            return @"del.icio.us";
        case SocialSiteMagnolia:
            return @"ma.gnolia.com";
        case SocialSitePinboard:
            return @"Pinboard";
        case SocialSiteLinkding:
            return @"Linkding";
        default:
            return @"Unknown";
    }
}

+ (NSString *)siteURLForSite:(SocialSite)site {
    switch (site) {
        case SocialSiteDelicious:
            return @"del.icio.us";
        case SocialSiteMagnolia:
            return @"ma.gnolia.com";
        case SocialSitePinboard:
            return @"pinboard.in";
        case SocialSiteLinkding:
            return @""; // Will be provided by user as host
        default:
            return nil;
    }
}

+ (NSString *)reversedSiteURLForSite:(SocialSite)site {
    switch (site) {
        case SocialSiteDelicious:
            return @"us.icio.del";
        case SocialSiteMagnolia:
            return @"com.gnolia.ma";
        case SocialSitePinboard:
            return @"in.pinboard";
        case SocialSiteLinkding:
            return @"linkding"; // Generic identifier
        default:
            return nil;
    }
}

@end