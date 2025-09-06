//
//  QSDeliciousAPIProvider.m
//  QSDeliciousPlugIn
//

#import "QSDeliciousAPIProvider.h"
#import "SocialSite.h"
#import <QSCore/QSCore.h>

@implementation QSDeliciousAPIProvider

- (instancetype)initWithSite:(SocialSite)site {
    self = [super init];
    if (self) {
        _site = site;
        _posts = [NSMutableArray array];
    }
    return self;
}

- (BOOL)canHandleSite:(SocialSite)site username:(NSString *)username password:(NSString *)password host:(NSString *)host {
    return (site == self.site) && 
           username.length > 0 && 
           password.length > 0 &&
           (site != SocialSiteLinkding); // This provider doesn't handle Linkding
}

- (SocialSite)supportedSite {
    return self.site;
}

- (NSString *)providerName {
    return [SocialSiteHelper displayNameForSite:self.site];
}

- (NSString *)apiURLForSite:(SocialSite)site {
    switch (site) {
        case SocialSiteDelicious:
            return @"api.del.icio.us/v1";
        case SocialSiteMagnolia:
            return @"ma.gnolia.com/api/mirrord/v1";
        case SocialSitePinboard:
            return @"api.pinboard.in/v1";
        default:
            return nil;
    }
}

- (NSURL *)requestURLForSite:(SocialSite)site username:(NSString *)username password:(NSString *)password host:(NSString *)host {
    NSString *apiURL = [self apiURLForSite:site];
    if (!apiURL) return nil;
    
    NSString *urlString = [NSString stringWithFormat:@"https://%@:%@@%@/posts/all?", username, password, apiURL];
    return [NSURL URLWithString:urlString];
}

- (NSData *)cachedBookmarkDataForSite:(SocialSite)site username:(NSString *)username {
    NSString *siteURL = [SocialSiteHelper siteURLForSite:site];
    NSString *cachePath = [QSApplicationSupportSubPath([NSString stringWithFormat:@"Caches/%@/", siteURL], NO) stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.xml", username]];
    return [NSData dataWithContentsOfFile:cachePath];
}

- (void)cacheBookmarkData:(NSData *)data forSite:(SocialSite)site username:(NSString *)username {
    NSString *siteURL = [SocialSiteHelper siteURLForSite:site];
    NSString *cachePath = [QSApplicationSupportSubPath([NSString stringWithFormat:@"Caches/%@/", siteURL], YES) stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.xml", username]];
    [data writeToFile:cachePath atomically:NO];
}

- (NSString *)tagURLType {
    return [NSString stringWithFormat:@"tag.%@", [SocialSiteHelper reversedSiteURLForSite:self.site]];
}

- (NSArray *)fetchBookmarksForSite:(SocialSite)site username:(NSString *)username password:(NSString *)password host:(NSString *)host includeTags:(BOOL)includeTags {
    
    // Try cached data first
    NSData *data = [self cachedBookmarkDataForSite:site username:username];
    
    // If no cached data, fetch from API
    if (![data length]) {
        NSURL *requestURL = [self requestURLForSite:site username:username password:password host:host];
        if (!requestURL) return @[];
        
        NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:requestURL
                                                                  cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                              timeoutInterval:60.0];
        [theRequest setHTTPMethod:@"POST"];
        [theRequest setValue:@"text/xml" forHTTPHeaderField:@"Content-type"];
        [theRequest setValue:@"Quicksilver (Blacktree,MacOSX)" forHTTPHeaderField:@"User-Agent"];
        
        NSError *error;
        data = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:nil error:&error];
        
        if (error) {
            NSLog(@"Error fetching bookmarks: %@", error.localizedDescription);
            return @[];
        }
        
        // Cache the data
        [self cacheBookmarkData:data forSite:site username:username];
    }
    
    // Parse XML data
    NSXMLParser *postParser = [[NSXMLParser alloc] initWithData:data];
    [postParser setDelegate:self];
    
    self.posts = [NSMutableArray arrayWithCapacity:1];
    [postParser parse];
    
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:1];
    NSMutableSet *tagSet = [NSMutableSet set];
    
    // Create bookmark objects
    for (NSDictionary *post in self.posts) {
        QSObject *newObject = [self objectForPost:post];
        if (newObject) {
            [objects addObject:newObject];
            
            // Collect tags if requested
            if (includeTags) {
                NSString *tagString = [post objectForKey:@"tag"];
                if (tagString.length > 0) {
                    [tagSet addObjectsFromArray:[tagString componentsSeparatedByString:@" "]];
                }
            }
        }
    }
    
    // Create tag objects if requested
    if (includeTags) {
        for (NSString *tag in tagSet) {
            if (tag.length > 0) {
                QSObject *tagObject = [QSObject makeObjectWithIdentifier:[NSString stringWithFormat:@"[%@ tag]:%@", [self providerName], tag]];
                [tagObject setObject:tag forType:[self tagURLType]];
                [tagObject setObject:username forMeta:[NSString stringWithFormat:@"%@.username", [SocialSiteHelper reversedSiteURLForSite:site]]];
                [tagObject setName:tag];
                [tagObject setPrimaryType:[self tagURLType]];
                [objects addObject:tagObject];
            }
        }
    }
    
    return objects;
}

- (NSArray *)fetchBookmarksForTag:(NSString *)tag site:(SocialSite)site username:(NSString *)username password:(NSString *)password host:(NSString *)host {
    NSData *data = [self cachedBookmarkDataForSite:site username:username];
    if (!data) return @[];
    
    NSXMLParser *postParser = [[NSXMLParser alloc] initWithData:data];
    [postParser setDelegate:self];
    self.posts = [NSMutableArray arrayWithCapacity:1];
    [postParser parse];
    
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:1];
    
    for (NSDictionary *post in self.posts) {
        NSString *postTags = [post objectForKey:@"tag"];
        if ([postTags rangeOfString:tag].location != NSNotFound) {
            QSObject *newObject = [self objectForPost:post];
            if (newObject) {
                [objects addObject:newObject];
            }
        }
    }
    
    return objects;
}

- (QSObject *)objectForPost:(NSDictionary *)post {
    QSObject *newObject = [QSObject makeObjectWithIdentifier:[post objectForKey:@"hash"]];
    [newObject setObject:[post objectForKey:@"href"] forType:QSURLType];
    [newObject setName:[post objectForKey:@"description"]];
    [newObject setDetails:[post objectForKey:@"extended"]];
    [newObject setPrimaryType:QSURLType];
    return newObject;
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser*)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqualToString:@"post"] && attributeDict) {
        [self.posts addObject:attributeDict];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    // Implementation if needed
}

@end
