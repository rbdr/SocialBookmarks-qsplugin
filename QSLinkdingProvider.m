//
//  QSLinkdingProvider.m
//  QSDeliciousPlugIn
//

#import "QSLinkdingProvider.h"
#import "SocialSite.h"
#import <QSCore/QSCore.h>

@implementation QSLinkdingProvider

- (BOOL)canHandleSite:(SocialSite)site username:(NSString *)username password:(NSString *)password host:(NSString *)host {
    return (site == SocialSiteLinkding) && 
           username.length > 0 && 
           password.length > 0 && // password is API token for Linkding
           host.length > 0;
}

- (SocialSite)supportedSite {
    return SocialSiteLinkding;
}

- (NSString *)providerName {
    return @"Linkding";
}

- (NSString *)tagURLType {
    return @"tag.linkding";
}

- (NSData *)cachedBookmarkDataForHost:(NSString *)host username:(NSString *)username {
    // Create a safe filename from host
    NSString *safeHost = [[host componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@"-"];
    NSString *cachePath = [QSApplicationSupportSubPath([NSString stringWithFormat:@"Caches/linkding/"], NO) stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.json", safeHost, username]];
    return [NSData dataWithContentsOfFile:cachePath];
}

- (void)cacheBookmarkData:(NSData *)data forHost:(NSString *)host username:(NSString *)username {
    // Create a safe filename from host
    NSString *safeHost = [[host componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@"-"];
    NSString *cachePath = [QSApplicationSupportSubPath([NSString stringWithFormat:@"Caches/linkding/"], YES) stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.json", safeHost, username]];
    [data writeToFile:cachePath atomically:NO];
}

- (NSArray *)fetchBookmarksForSite:(SocialSite)site username:(NSString *)username password:(NSString *)password host:(NSString *)host includeTags:(BOOL)includeTags {
    
    if (![self canHandleSite:site username:username password:password host:host]) {
        return @[];
    }
    
    // Try cached data first
    NSData *data = [self cachedBookmarkDataForHost:host username:username];
    
    // If no cached data, fetch from API
    if (![data length]) {
        // Construct Linkding API URL
        NSString *baseURL = host;
        if (![baseURL hasPrefix:@"http://"] && ![baseURL hasPrefix:@"https://"]) {
            baseURL = [NSString stringWithFormat:@"https://%@", baseURL];
        }
        if ([baseURL hasSuffix:@"/"]) {
            baseURL = [baseURL substringToIndex:[baseURL length] - 1];
        }
        
        NSString *urlString = [NSString stringWithFormat:@"%@/api/bookmarks/", baseURL];
        NSURL *requestURL = [NSURL URLWithString:urlString];
        
        if (!requestURL) {
            NSLog(@"Invalid Linkding host URL: %@", host);
            return @[];
        }
      
      NSLog(@"WE ARE ABOUT TO REQUEST TO URL: %@", requestURL);
      
        NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:requestURL
                                                                  cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                              timeoutInterval:60.0];
        [theRequest setHTTPMethod:@"GET"];
        [theRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [theRequest setValue:[NSString stringWithFormat:@"Token %@", password] forHTTPHeaderField:@"Authorization"];
        [theRequest setValue:@"Quicksilver (Blacktree,MacOSX)" forHTTPHeaderField:@"User-Agent"];
        
        NSError *error = nil;
        data = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:nil error:&error];
        
        if (error) {
            NSLog(@"Error fetching Linkding bookmarks: %@", error.localizedDescription);
            return @[];
        }
        
        // Cache the data
        [self cacheBookmarkData:data forHost:host username:username];
    }
    
    // Parse JSON data
    NSError *jsonError = nil;
    NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
    if (jsonError) {
        NSLog(@"Error parsing Linkding JSON: %@", jsonError.localizedDescription);
        return @[];
    }
    
    NSArray *results = [jsonResponse objectForKey:@"results"];
    if (!results || ![results isKindOfClass:[NSArray class]]) {
        NSLog(@"Invalid Linkding response format");
        return @[];
    }
    
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:1];
    NSMutableSet *tagSet = [NSMutableSet set];
    
    // Create bookmark objects
    for (NSDictionary *bookmark in results) {
        QSObject *newObject = [self objectForLinkdingBookmark:bookmark];
        if (newObject) {
            [objects addObject:newObject];
            
            // Collect tags if requested
            if (includeTags) {
                NSArray *tags = [bookmark objectForKey:@"tag_names"];
                if (tags && [tags isKindOfClass:[NSArray class]]) {
                    [tagSet addObjectsFromArray:tags];
                }
            }
        }
    }
    
    // Create tag objects if requested
    if (includeTags) {
        for (NSString *tag in tagSet) {
            if (tag.length > 0) {
                QSObject *tagObject = [QSObject makeObjectWithIdentifier:[NSString stringWithFormat:@"[Linkding tag]:%@", tag]];
                [tagObject setObject:tag forType:[self tagURLType]];
                [tagObject setObject:username forMeta:@"linkding.username"];
                [tagObject setObject:host forMeta:@"linkding.host"];
                [tagObject setName:tag];
                [tagObject setPrimaryType:[self tagURLType]];
                [objects addObject:tagObject];
            }
        }
    }
    
    return objects;
}

- (NSArray *)fetchBookmarksForTag:(NSString *)tag site:(SocialSite)site username:(NSString *)username password:(NSString *)password host:(NSString *)host {
    NSData *data = [self cachedBookmarkDataForHost:host username:username];
    if (!data) return @[];
    
    NSError *jsonError;
    NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
    if (jsonError) return @[];
    
    NSArray *results = [jsonResponse objectForKey:@"results"];
    if (!results || ![results isKindOfClass:[NSArray class]]) return @[];
    
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:1];
    
    for (NSDictionary *bookmark in results) {
        NSArray *tags = [bookmark objectForKey:@"tag_names"];
        if (tags && [tags isKindOfClass:[NSArray class]] && [tags containsObject:tag]) {
            QSObject *newObject = [self objectForLinkdingBookmark:bookmark];
            if (newObject) {
                [objects addObject:newObject];
            }
        }
    }
    
    return objects;
}

- (QSObject *)objectForLinkdingBookmark:(NSDictionary *)bookmark {
    NSNumber *bookmarkId = [bookmark objectForKey:@"id"];
    NSString *url = [bookmark objectForKey:@"url"];
    NSString *title = [bookmark objectForKey:@"title"];
    NSString *description = [bookmark objectForKey:@"description"];
    
    if (!bookmarkId || !url) return nil;
    
    QSObject *newObject = [QSObject makeObjectWithIdentifier:[NSString stringWithFormat:@"linkding-%@", bookmarkId]];
    [newObject setObject:url forType:QSURLType];
    [newObject setName:title.length > 0 ? title : url];
    [newObject setDetails:description.length > 0 ? description : @""];
    [newObject setPrimaryType:QSURLType];
    
    return newObject;
}

@end
