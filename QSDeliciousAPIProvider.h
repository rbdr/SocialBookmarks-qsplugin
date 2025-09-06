//
//  QSDeliciousAPIProvider.h
//  QSDeliciousPlugIn
//
//  Base provider for Pinboard v1 API (XML-based with Basic Auth)
//  Used by Delicious, Magnolia, and Pinboard
//

#import <Foundation/Foundation.h>
#import "QSBookmarkProvider.h"

@interface QSDeliciousAPIProvider : NSObject <QSBookmarkProvider, NSXMLParserDelegate>

@property (nonatomic, strong) NSMutableArray *posts;
@property (nonatomic, assign) SocialSite site;

- (instancetype)initWithSite:(SocialSite)site;

// Subclasses can override these methods
- (NSString *)apiURLForSite:(SocialSite)site;
- (NSURL *)requestURLForSite:(SocialSite)site username:(NSString *)username password:(NSString *)password host:(NSString *)host;
- (NSData *)cachedBookmarkDataForSite:(SocialSite)site username:(NSString *)username;
- (void)cacheBookmarkData:(NSData *)data forSite:(SocialSite)site username:(NSString *)username;

@end
