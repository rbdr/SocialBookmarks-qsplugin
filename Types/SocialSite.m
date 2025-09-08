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

+ (NSString *)siteURLForSite:(SocialSite)site {
    switch (site) {
        case SocialSiteDelicious:
            return @"del.icio.us";
        case SocialSiteMagnolia:
            return @"ma.gnolia.com";
        case SocialSitePinboard:
            return @"pinboard.in";
        case SocialSiteSelfHostedDeliciousCompatible:
        case SocialSiteLinkding:
            return @""; // Will be provided by user as host
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
