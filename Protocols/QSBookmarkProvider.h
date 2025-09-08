//
//  QSBookmarkProvider.h
//  QSDeliciousPlugIn
//
//  Protocol for social bookmark providers
//

#import "SocialSite.h"
#import <Foundation/Foundation.h>

@class QSObject;

@protocol QSBookmarkProvider <NSObject>

@required
/**
 * Check if this provider can handle the given site configuration
 */
- (BOOL)canHandleSite:(SocialSite)site
             username:(NSString *)username
             password:(NSString *)password
                 host:(NSString *)host;

/**
 * Fetch bookmarks for the given configuration
 * Returns an NSArray of QSObject instances
 */
- (NSArray *)fetchBookmarksForSite:(SocialSite)site
                          username:(NSString *)username
                          password:(NSString *)password
                        identifier:(NSString *)identifier
                              host:(NSString *)host
                       includeTags:(BOOL)includeTags;

@optional
/**
 * Get bookmarks for a specific tag (used for child loading)
 */
- (NSArray *)fetchBookmarksForTag:(NSString *)tag
                             site:(SocialSite)site
                         username:(NSString *)username
                         password:(NSString *)password
                             host:(NSString *)host;

@end
