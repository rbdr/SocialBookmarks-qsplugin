//
//  QSLinkdingProvider.h
//  QSDeliciousPlugIn
//
//  Provider for Linkding API (JSON-based with API key)
//

#import "QSBookmarkProvider.h"
#import <Foundation/Foundation.h>

@interface QSLinkdingProvider : NSObject <QSBookmarkProvider>

- (NSData *)cachedBookmarkDataForHost:(NSString *)host
                             username:(NSString *)username;
- (void)cacheBookmarkData:(NSData *)data
                  forHost:(NSString *)host
                 username:(NSString *)username;

@end