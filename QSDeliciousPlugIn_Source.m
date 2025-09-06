//
//  QSDeliciousPlugIn_Source.m
//  QSDeliciousPlugIn
//
//  Created by Nicholas Jitkoff on 9/18/04.
//  Copyright __MyCompanyName__ 2004. All rights reserved.
//

#import "QSDeliciousPlugIn_Source.h"
#import <QSCore/QSCore.h>
#import <Security/Security.h>

@implementation QSDeliciousPlugIn_Source

+ (void)initialize {
  [self setKeys:[NSArray arrayWithObject:@"selection"] triggerChangeNotificationsForDependentKey:@"currentPassword"];
}

- (BOOL)indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry {
  return -[indexDate timeIntervalSinceNow] < 24 * 60 * 60;
}

- (BOOL)isVisibleSource{
    return YES;
}

- (NSImage *) iconForEntry:(NSDictionary *)dict {
    return [[NSBundle bundleForClass:[self class]]imageNamed:@"bookmark_icon"];
}

- (NSView *)settingsView
{
  if (![super settingsView]) {
    [[NSBundle bundleForClass:[self class]] loadNibNamed:NSStringFromClass([self class]) owner:self topLevelObjects:NULL];
  }
  return [super settingsView];
}

#pragma mark - Settings Helpers

- (SocialSite)siteIndex {
  NSDictionary *settings = self.selectedEntry.sourceSettings;
  return [settings objectForKey:@"site"] != nil ? [[settings objectForKey:@"site"] integerValue] : SocialSiteDelicious;
}

- (NSString *)currentUsername {
  return [self.selectedEntry.sourceSettings objectForKey:@"username"];
}

- (NSString *)currentHost {
  return [self.selectedEntry.sourceSettings objectForKey:@"host"];
}

- (NSString *)currentPassword {
  return [self.selectedEntry.sourceSettings objectForKey:@"password"];
}

- (BOOL)includeTags {
    return [[self.selectedEntry.sourceSettings objectForKey:@"includeTags"] boolValue];
}

#pragma mark - Keychain Access

- (SecProtocolType)protocolTypeForString:(NSString *)protocol {
  if ([protocol isEqualToString:@"ftp"]) return kSecProtocolTypeFTP;
  else if ([protocol isEqualToString:@"http"]) return kSecProtocolTypeHTTP;
  else if ([protocol isEqualToString:@"sftp"]) return kSecProtocolTypeFTPS;
  else if ([protocol isEqualToString:@"eppc"]) return kSecProtocolTypeEPPC;
  else if ([protocol isEqualToString:@"afp"]) return kSecProtocolTypeAFP;
  else if ([protocol isEqualToString:@"smb"]) return kSecProtocolTypeSMB;
  else if ([protocol isEqualToString:@"ssh"]) return kSecProtocolTypeSSH;
  else if ([protocol isEqualToString:@"telnet"]) return kSecProtocolTypeTelnet;
  return 0;
}

- (NSString *)passwordForHost:(NSString *)host user:(NSString *)user andType:(SecProtocolType)type {
  const char     *buffer;
  UInt32       length = 0;
  OSErr      err;
  
  err = SecKeychainFindInternetPassword(NULL,
                      (UInt32)[host length], [host UTF8String],
                      0,
                      NULL,
                      (UInt32)[user length], [user UTF8String],
                      0, NULL,
                      0,
                      type,
                      0,
                      &length, (void**)&buffer,
                      NULL);
  
  if (err == noErr) {
    NSString *password = [NSString stringWithUTF8String:buffer];
    SecKeychainItemFreeContent(NULL,(void *)buffer);
    return password;
  }
  return nil;
}

- (NSString *)passwordForHost:(NSString *)host user:(NSString *)user andScheme:(NSString *)scheme {
  NSString *password = nil;
  
  SecProtocolType type = [self protocolTypeForString:scheme];
  
  password = [self passwordForHost:host user:user andType:type];
  
  if (!password && type == kSecProtocolTypeFTP)
    password = [self passwordForHost:host user:user andType:kSecProtocolTypeFTPAccount]; // Workaround for Transmit's old type usage
  if ( !password )
    password = [self passwordForHost:host user:user andType:0];
  if ( !password )
    NSLog(@"Couldn't find password. URL:%@ %@ %@", host, user,scheme );
  return password;
}

- (NSString *)keychainPasswordForURL:(NSURL *)url {
  return [self passwordForHost:[url host] user:[url user] andScheme:[url scheme]];
}

- (OSErr)addURLPasswordToKeychain:(NSURL *)url {
  OSErr      err;
  
  NSString *host = [url host];
  NSString *user = [url user];
  NSString *pass = [url password];
  
  SecProtocolType type = [self protocolTypeForString:[url scheme]];
  
  SecKeychainItemRef existing = NULL;
  
  err = SecKeychainFindInternetPassword(NULL,
                      (UInt32)[host length], [host UTF8String],
                      0, NULL,
                      (UInt32)[user length], [user UTF8String],
                      0, NULL,
                      0,
                      type,
                      0,
                      NULL,NULL,
                      &existing);
  
  if ( !err ) {
    err = SecKeychainItemModifyContent( existing, NULL, (UInt32)[pass length], [pass UTF8String] );
    CFRelease( existing );
  } else {
    err = SecKeychainAddInternetPassword(NULL,
                                             (UInt32)[host length], [host UTF8String],
                                             0, NULL,
                                             (UInt32)[user length], [user UTF8String],
                                             0, NULL,
                                             0,
                                             type,
                                             0,
                                             (UInt32)[pass length], [pass UTF8String],
                                             NULL);
    }
  
  return err;
}

- (NSString *)oldCurrentPassword {
  NSString *account = [self currentUsername];
  if (!account) return nil;
  
    SocialSite site = [self siteIndex];
    NSString *host = nil;
    
    // For Linkding, use the custom host; for others, use the standard site URL
    if (site == SocialSiteLinkding) {
        host = [self currentHost];
        if (!host) return nil;
    } else {
        host = [SocialSiteHelper siteURLForSite:site];
    }
  
  NSURL *keychainURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@@%@/", account, host]];
  NSString *password = [self keychainPasswordForURL:keychainURL];
  
  return password;
}

- (void)setCurrentPassword:(NSString *)newPassword {
  NSString *account = [self currentUsername];
  if (!account) return;
  if ([newPassword length] <= 0) return;
  
    SocialSite site = [self siteIndex];
    NSString *host = nil;
    
    // For Linkding, use the custom host; for others, use the standard site URL
    if (site == SocialSiteLinkding) {
        host = [self currentHost];
        if (!host) return;
    } else {
        host = [SocialSiteHelper siteURLForSite:site];
    }
  
  NSURL *keychainURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%@@%@/", account, newPassword, host]];
  
  [self addURLPasswordToKeychain:keychainURL];
}

#pragma mark - Objects For Entry

- (NSArray *)objectsForEntry:(NSDictionary *)theEntry {
  NSLog(@"WE HAVE BEEN REQUESTED");
    SocialSite site = [self siteIndex];
    NSString *username = [self currentUsername];
    NSString *password = [self currentPassword];
    NSString *host = [self currentHost];
    BOOL includeTags = [self includeTags];
    
    // Get the appropriate provider using the factory
    QSBookmarkProviderFactory *factory = [QSBookmarkProviderFactory sharedFactory];
    id<QSBookmarkProvider> provider = [factory providerForSite:site username:username password:password host:host];
    
  NSLog(@"Checking for %ld, user %@, pass %@, host %@", (long)site, username, password, host);
    if (!provider) {
        NSLog(@"No provider available for site %ld with username %@", (long)site, username);
        return @[];
    }
    
    return [provider fetchBookmarksForSite:site username:username password:password host:host includeTags:includeTags];
}

- (NSArray *)objectsForTag:(NSString *)tag username:(NSString *)username {
    SocialSite site = [self siteIndex];
    NSString *password = [self currentPassword];
    NSString *host = [self currentHost];
    
    // Get the appropriate provider using the factory
    QSBookmarkProviderFactory *factory = [QSBookmarkProviderFactory sharedFactory];
    id<QSBookmarkProvider> provider = [factory providerForSite:site username:username password:password host:host];
    
    if (!provider) {
        NSLog(@"No provider available for site %ld with username %@", (long)site, username);
        return @[];
    }
    
    // Check if provider supports tag-based fetching
    if ([provider respondsToSelector:@selector(fetchBookmarksForTag:site:username:password:host:)]) {
        return [provider fetchBookmarksForTag:tag site:site username:username password:password host:host];
    }
    
    return @[];
}

#pragma mark - Object Handler Methods

- (void)setQuickIconForObject:(QSObject *)object {
  [object setIcon:[[NSBundle bundleForClass:[self class]]imageNamed:@"bookmark_icon"]];
}

- (BOOL)loadChildrenForObject:(QSObject *)object {
    SocialSite site = [self siteIndex];
    
    NSString *tagType = nil;
    if (site == SocialSiteLinkding) {
        tagType = @"tag.linkding";
    } else {
        NSString *reversedURL = [SocialSiteHelper reversedSiteURLForSite:site];
        tagType = [NSString stringWithFormat:@"tag.%@", reversedURL];
    }
    
    NSString *tag = [object objectForType:tagType];
    if (!tag) return NO;
    
    NSString *username = nil;
    if (site == SocialSiteLinkding) {
        username = [object objectForMeta:@"linkding.username"];
    } else {
        NSString *reversedURL = [SocialSiteHelper reversedSiteURLForSite:site];
        username = [object objectForMeta:[NSString stringWithFormat:@"%@.username", reversedURL]];
    }
    
    if (!username) return NO;
    
    NSArray *children = [self objectsForTag:tag username:username];
    [object setChildren:children];
    return YES;
}

@end
