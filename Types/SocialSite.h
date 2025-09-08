//
//  SocialSite.h
//  QSDeliciousPlugIn
//
//  Social bookmark site enumeration
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SocialSite) {
  SocialSiteDelicious = 0,
  SocialSiteMagnolia = 1,
  SocialSitePinboard = 2,
  SocialSiteLinkding = 3,
  SocialSiteSelfHostedDeliciousCompatible = 4
};

@interface SocialSiteHelper : NSObject

+ (NSString *)displayNameForSite:(SocialSite)site;
+ (NSString *)cacheKeyForSite:(SocialSite)site;
+ (BOOL)hasVariableHost:(SocialSite)site;

@end
