//
//  QSLinkdingProvider.m
//  QSDeliciousPlugIn
//

#import "QSLinkdingProvider.h"
#import "Constants.h"
#import "SocialSite.h"
#import <QSCore/QSCore.h>

@implementation QSLinkdingProvider

- (BOOL)canHandleSite:(SocialSite)site
             username:(NSString *)username
             password:(NSString *)password
                 host:(NSString *)host {
  return (site == SocialSiteLinkding) && username.length > 0 &&
         password.length > 0 && // password is API token for Linkding
         host.length > 0;
}

- (NSData *)cachedBookmarkDataForHost:(NSString *)host
                             username:(NSString *)username {
  // Create a safe filename from host
  NSString *safeHost =
      [[host componentsSeparatedByCharactersInSet:[[NSCharacterSet
                                                      alphanumericCharacterSet]
                                                      invertedSet]]
          componentsJoinedByString:@"-"];
  NSString *cachePath = [QSApplicationSupportSubPath(
      [NSString stringWithFormat:@"Caches/linkding/"], NO)
      stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.json",
                                                                safeHost,
                                                                username]];
  return [NSData dataWithContentsOfFile:cachePath];
}

- (void)cacheBookmarkData:(NSData *)data
                  forHost:(NSString *)host
                 username:(NSString *)username {
  // Create a safe filename from host
  NSString *safeHost =
      [[host componentsSeparatedByCharactersInSet:[[NSCharacterSet
                                                      alphanumericCharacterSet]
                                                      invertedSet]]
          componentsJoinedByString:@"-"];
  NSString *cachePath = [QSApplicationSupportSubPath(
      [NSString stringWithFormat:@"Caches/linkding/"], YES)
      stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.json",
                                                                safeHost,
                                                                username]];
  [data writeToFile:cachePath atomically:NO];
}

- (NSArray *)fetchBookmarksForSite:(SocialSite)site
                          username:(NSString *)username
                          password:(NSString *)password
                        identifier:(NSString *)identifier
                              host:(NSString *)host
                       includeTags:(BOOL)includeTags {

  if (![self canHandleSite:site
                  username:username
                  password:password
                      host:host]) {
    return @[];
  }

  NSData *data = [self cachedBookmarkDataForHost:host username:username];

  if (![data length]) {
    NSString *baseURL = host;
    if (![baseURL hasPrefix:@"http://"] && ![baseURL hasPrefix:@"https://"]) {
      baseURL = [NSString stringWithFormat:@"https://%@", baseURL];
    }
    if ([baseURL hasSuffix:@"/"]) {
      baseURL = [baseURL substringToIndex:[baseURL length] - 1];
    }

    // I'm being lazy with the limit for now. This should instead loop while
    // there is a next, but then the caching will also need to be changed. If
    // you have a particularly large linkding library, I apologize.
    NSString *urlString =
        [NSString stringWithFormat:@"%@/api/bookmarks/?limit=10000", baseURL];
    NSURL *requestURL = [NSURL URLWithString:urlString];

    if (!requestURL) {
      NSLog(@"Invalid Linkding host URL: %@", host);
      return @[];
    }

    NSMutableURLRequest *theRequest =
        [NSMutableURLRequest requestWithURL:requestURL
                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                            timeoutInterval:60.0];
    [theRequest setHTTPMethod:@"GET"];
    [theRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [theRequest setValue:[NSString stringWithFormat:@"Token %@", password]
        forHTTPHeaderField:@"Authorization"];
    [theRequest setValue:@"Quicksilver (Blacktree,MacOSX)"
        forHTTPHeaderField:@"User-Agent"];

    NSError *error = nil;
    data = [NSURLConnection sendSynchronousRequest:theRequest
                                 returningResponse:nil
                                             error:&error];

    if (error) {
      NSLog(@"Error fetching Linkding bookmarks: %@",
            error.localizedDescription);
      return @[];
    }

    [self cacheBookmarkData:data forHost:host username:username];
  }

  NSError *jsonError = nil;
  NSDictionary *jsonResponse =
      [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

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

  for (NSDictionary *bookmark in results) {
    QSObject *newObject = [self objectForLinkdingBookmark:bookmark];
    if (newObject) {
      [objects addObject:newObject];

      if (includeTags) {
        NSArray *tags = [bookmark objectForKey:@"tag_names"];
        if (tags && [tags isKindOfClass:[NSArray class]]) {
          [tagSet addObjectsFromArray:tags];
        }
      }
    }
  }

  if (includeTags) {
    for (NSString *tag in tagSet) {
      if (tag.length > 0) {
        QSObject *tagObject = [QSObject
            makeObjectWithIdentifier:[NSString
                                         stringWithFormat:@"[Linkding tag]:%@",
                                                          tag]];
        [tagObject setObject:tag forType:kTagType];
        [tagObject setObject:@(site) forMeta:kTagSiteField];
        [tagObject setObject:username forMeta:kTagUsernameField];
        [tagObject setObject:host forMeta:kTagHostField];
        // We need the identifier to be able to fetch the keychain password
        [tagObject setObject:identifier forMeta:kTagIdentifierField];
        [tagObject setName:tag];
        [tagObject setPrimaryType:kTagType];
        [objects addObject:tagObject];
      }
    }
  }

  return objects;
}

- (NSArray *)fetchBookmarksForTag:(NSString *)tag
                             site:(SocialSite)site
                         username:(NSString *)username
                         password:(NSString *)password
                             host:(NSString *)host {
  NSData *data = [self cachedBookmarkDataForHost:host username:username];
  if (!data)
    return @[];

  NSError *jsonError;
  NSDictionary *jsonResponse =
      [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

  if (jsonError)
    return @[];

  NSArray *results = [jsonResponse objectForKey:@"results"];
  if (!results || ![results isKindOfClass:[NSArray class]])
    return @[];

  NSMutableArray *objects = [NSMutableArray arrayWithCapacity:1];

  for (NSDictionary *bookmark in results) {
    NSArray *tags = [bookmark objectForKey:@"tag_names"];
    if (tags && [tags isKindOfClass:[NSArray class]] &&
        [tags containsObject:tag]) {
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

  if (!bookmarkId || !url)
    return nil;

  QSObject *newObject = [QSObject
      makeObjectWithIdentifier:[NSString stringWithFormat:@"linkding-%@",
                                                          bookmarkId]];
  [newObject setObject:url forType:QSURLType];
  [newObject setName:title.length > 0 ? title : url];
  [newObject setDetails:description.length > 0 ? description : @""];
  [newObject setPrimaryType:QSURLType];

  return newObject;
}

@end
