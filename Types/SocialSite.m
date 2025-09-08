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
        case SocialSiteSelfHostedDeliciousCompatible:
          return @"Self-Hosted (Delicious Compatible)";
        default:
            return @"Unknown";
    }
}

// This is used for caching key
+ (NSString *)cacheKeyForSite:(SocialSite)site {
    switch (site) {
        case SocialSiteDelicious:
            return @"del.icio.us";
        case SocialSiteMagnolia:
            return @"ma.gnolia.com";
        case SocialSitePinboard:
            return @"pinboard.in";
        case SocialSiteSelfHostedDeliciousCompatible:
        return @"self-hosted-delicious";
        case SocialSiteLinkding:
            return @"linkding";
        default:
            return nil;
    }
}

+ (BOOL)hasVariableHost:(SocialSite)site {
    switch (site) {
      case SocialSiteSelfHostedDeliciousCompatible:
      case SocialSiteLinkding:
        return YES;
      default:
        return NO;
    }
}

@end
