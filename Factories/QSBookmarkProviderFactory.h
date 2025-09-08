//
//  QSBookmarkProviderFactory.h
//  QSDeliciousPlugIn
//
//  Factory for managing bookmark providers
//

#import <Foundation/Foundation.h>
#import "QSBookmarkProvider.h"
#import "SocialSite.h"

@interface QSBookmarkProviderFactory : NSObject

@property (nonatomic, strong, readonly) NSArray<id<QSBookmarkProvider>> *providers;

+ (instancetype)sharedFactory;

/**
 * Get the appropriate provider for the given site configuration
 */
- (id<QSBookmarkProvider>)providerForSite:(SocialSite)site username:(NSString *)username password:(NSString *)password host:(NSString *)host;

/**
 * Get all available providers
 */
- (NSArray<id<QSBookmarkProvider>> *)allProviders;

@end