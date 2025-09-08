//
//  QSDeliciousAPIProvider.m
//  QSDeliciousPlugIn
//

#import "QSDeliciousAPIProvider.h"
#import "Constants.h"
#import "SocialSite.h"
#import <QSCore/QSCore.h>

@implementation QSDeliciousAPIProvider

- (BOOL)canHandleSite:(SocialSite)site
             username:(NSString *)username
             password:(NSString *)password
                 host:(NSString *)host {
  return (site == SocialSiteDelicious || site == SocialSiteMagnolia ||
          site == SocialSitePinboard ||
          site == SocialSiteSelfHostedDeliciousCompatible) &&
         username.length > 0 && password.length > 0 &&
         (site != SocialSiteSelfHostedDeliciousCompatible || host.length > 0);
}

- (NSString *)apiURLForSite:(SocialSite)site andHost:(NSString *)host {
  switch (site) {
  case SocialSiteDelicious:
    return @"api.del.icio.us/v1";
  case SocialSiteMagnolia:
    return @"ma.gnolia.com/api/mirrord/v1";
  case SocialSitePinboard:
    return @"https://api.pinboard.in/v1";
  case SocialSiteSelfHostedDeliciousCompatible:
    return [NSString stringWithFormat:@"%@/v1", host];
  default:
    return nil;
  }
}
- (BOOL)usesAuthToken:(SocialSite)site {
  switch (site) {
  case SocialSitePinboard:
  case SocialSiteSelfHostedDeliciousCompatible:
    return YES;
  default:
    return NO;
  }
}

- (NSURL *)requestURLForSite:(SocialSite)site
                    username:(NSString *)username
                    password:(NSString *)password
                        host:(NSString *)host {
  NSString *apiURL = [self apiURLForSite:site andHost:host];
  if (!apiURL)
    return nil;

  NSString *urlString;
  if ([self usesAuthToken:site]) {
    // Pinboard and pinboard compatible sites require an
    // auth token rather than a password.
    urlString = [NSString
        stringWithFormat:@"%@/posts/all?auth_token=%@", apiURL, password];
  } else {
    urlString = [NSString stringWithFormat:@"https://%@:%@@%@/posts/all?",
                                           username, password, apiURL];
  }
  return [NSURL URLWithString:urlString];
}

#pragma mark - Cache

- (NSString *)cachePathForSite:(SocialSite)site
                      username:(NSString *)username
                          host:(NSString *)host
                        create:(BOOL)create {

  NSString *siteURL = [SocialSiteHelper cacheKeyForSite:site];
  NSString *safeHost =
      [[host componentsSeparatedByCharactersInSet:[[NSCharacterSet
                                                      alphanumericCharacterSet]
                                                      invertedSet]]
          componentsJoinedByString:@"-"];
  return [QSApplicationSupportSubPath(
      [NSString stringWithFormat:@"Caches/%@/", siteURL], create)
      stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.xml",
                                                                safeHost,
                                                                username]];
}

- (NSData *)cachedBookmarkDataForSite:(SocialSite)site
                             username:(NSString *)username
                                 host:(NSString *)host {
  NSString *cachePath = [self cachePathForSite:site
                                      username:username
                                          host:host
                                        create:NO];
  return [NSData dataWithContentsOfFile:cachePath];
}

- (void)cacheBookmarkData:(NSData *)data
                  forSite:(SocialSite)site
                 username:(NSString *)username
                     host:(NSString *)host {
  NSString *cachePath = [self cachePathForSite:site
                                      username:username
                                          host:host
                                        create:YES];
  [data writeToFile:cachePath atomically:NO];
}

- (NSArray *)fetchBookmarksForSite:(SocialSite)site
                          username:(NSString *)username
                          password:(NSString *)password
                        identifier:(NSString *)identifier
                              host:(NSString *)host
                       includeTags:(BOOL)includeTags {

  NSData *data = [self cachedBookmarkDataForSite:site
                                        username:username
                                            host:host];

  if (![data length]) {
    NSURL *requestURL = [self requestURLForSite:site
                                       username:username
                                       password:password
                                           host:host];
    if (!requestURL)
      return @[];

    NSMutableURLRequest *theRequest =
        [NSMutableURLRequest requestWithURL:requestURL
                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                            timeoutInterval:60.0];
    [theRequest setHTTPMethod:@"GET"];
    [theRequest setValue:@"text/xml" forHTTPHeaderField:@"Content-type"];
    [theRequest setValue:@"Quicksilver (Blacktree,MacOSX)"
        forHTTPHeaderField:@"User-Agent"];

    NSError *error = nil;
    data = [NSURLConnection sendSynchronousRequest:theRequest
                                 returningResponse:nil
                                             error:&error];

    if (error) {
      NSLog(@"Error fetching bookmarks: %@", error.localizedDescription);
      return @[];
    }

    [self cacheBookmarkData:data forSite:site username:username host:host];
  }

  NSXMLParser *postParser = [[NSXMLParser alloc] initWithData:data];
  [postParser setDelegate:self];

  self.posts = [NSMutableArray arrayWithCapacity:1];
  [postParser parse];

  NSMutableArray *objects = [NSMutableArray arrayWithCapacity:1];
  NSMutableSet *tagSet = [NSMutableSet set];

  for (NSDictionary *post in self.posts) {
    QSObject *newObject = [self objectForPost:post];
    if (newObject) {
      [objects addObject:newObject];

      if (includeTags) {
        NSString *tagString = [post objectForKey:@"tag"];
        if (tagString.length > 0) {
          [tagSet
              addObjectsFromArray:[tagString componentsSeparatedByString:@" "]];
        }
      }
    }
  }

  if (includeTags) {
    for (NSString *tag in tagSet) {
      if (tag.length > 0) {
        QSObject *tagObject = [QSObject
            makeObjectWithIdentifier:
                [NSString
                    stringWithFormat:@"[%@ tag]:%@",
                                     [SocialSiteHelper displayNameForSite:site],
                                     tag]];

        [tagObject setObject:tag forType:kTagType];
        [tagObject setObject:@(site) forMeta:kTagSiteField];
        [tagObject setObject:username forMeta:kTagUsernameField];
        [tagObject setObject:host forMeta:kTagHostField];
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
  NSData *data = [self cachedBookmarkDataForSite:site
                                        username:username
                                            host:host];
  if (!data)
    return @[];

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
  QSObject *newObject =
      [QSObject makeObjectWithIdentifier:[post objectForKey:@"hash"]];
  [newObject setObject:[post objectForKey:@"href"] forType:QSURLType];
  [newObject setName:[post objectForKey:@"description"]];
  [newObject setDetails:[post objectForKey:@"extended"]];
  [newObject setPrimaryType:QSURLType];
  return newObject;
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser
    didStartElement:(NSString *)elementName
       namespaceURI:(NSString *)namespaceURI
      qualifiedName:(NSString *)qName
         attributes:(NSDictionary *)attributeDict {
  if ([elementName isEqualToString:@"post"] && attributeDict) {
    [self.posts addObject:attributeDict];
  }
}

- (void)parser:(NSXMLParser *)parser
    didEndElement:(NSString *)elementName
     namespaceURI:(NSString *)namespaceURI
    qualifiedName:(NSString *)qName {
  // Implementation if needed
}

@end
