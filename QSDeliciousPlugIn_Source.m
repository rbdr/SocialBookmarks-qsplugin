//
//  QSDeliciousPlugIn_Source.m
//  QSDeliciousPlugIn
//
//  Created by Nicholas Jitkoff on 9/18/04.
//  Copyright __MyCompanyName__ 2004. All rights reserved.
//

#import "QSDeliciousPlugIn_Source.h"
#import "Constants.h"
#import <QSCore/QSCore.h>
#import <Security/Security.h>

@implementation QSDeliciousPlugIn_Source

#pragma mark - Lifecycle

// This method will get called whenever we change which
// active entry is selected.
- (void)setSelectedEntry:(id)selectedEntry {
    [super setSelectedEntry:selectedEntry];
    [self loadPasswordFromKeychain];
}

#pragma mark - Quicksilver Source Methods

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
  return self.internalPassword;
}

- (BOOL)includeTags {
    return [[self.selectedEntry.sourceSettings objectForKey:@"includeTags"] boolValue];
}


// This method is called on action from all the NIB methods
// to force the catalog to save the current values.
- (IBAction)settingsChanged:(id)sender {
  [[NSNotificationCenter defaultCenter] postNotificationName:QSCatalogEntryChangedNotification object:self.selectedEntry];
  [self willChangeValueForKey:@"isHostVisible"];
  [self didChangeValueForKey:@"isHostVisible"];
}


#pragma mark - Keychain Helper Methods

- (NSString *)keychainKeyForIdentifier:(NSString *)identifier {
    return [NSString stringWithFormat:@"QSSocialBookmarks-%@", identifier];
}

- (NSString *)passwordFromKeychainForKey:(NSString *)key {
    const char *service = "QSSocialBookmarks";
    const char *account = [key UTF8String];
    
    UInt32 passwordLength = 0;
    void *passwordData = NULL;
    
    OSStatus status = SecKeychainFindGenericPassword(NULL,
                                                   (UInt32)strlen(service), service,
                                                   (UInt32)strlen(account), account,
                                                   &passwordLength, &passwordData,
                                                   NULL);
    
    if (status == errSecSuccess && passwordData != NULL) {
        NSString *password = [[NSString alloc] initWithBytes:passwordData
                                                      length:passwordLength
                                                    encoding:NSUTF8StringEncoding];
        SecKeychainItemFreeContent(NULL, passwordData);
        return password;
    }
    
    return nil;
}

- (OSStatus)savePasswordToKeychainForKey:(NSString *)key password:(NSString *)password {
    const char *service = "QSSocialBookmarks";
    const char *account = [key UTF8String];
    const char *passwordCString = [password UTF8String];
    
    // First try to find existing item
    SecKeychainItemRef item = NULL;
    OSStatus findStatus = SecKeychainFindGenericPassword(NULL,
                                                       (UInt32)strlen(service), service,
                                                       (UInt32)strlen(account), account,
                                                       NULL, NULL,
                                                       &item);
    
    OSStatus status;
    if (findStatus == errSecSuccess) {
        // Update existing item
        status = SecKeychainItemModifyAttributesAndData(item,
                                                      NULL,
                                                      (UInt32)strlen(passwordCString),
                                                      passwordCString);
        CFRelease(item);
    } else {
        // Create new item
        status = SecKeychainAddGenericPassword(NULL,
                                             (UInt32)strlen(service), service,
                                             (UInt32)strlen(account), account,
                                             (UInt32)strlen(passwordCString), passwordCString,
                                             NULL);
    }
    
    return status;
}

- (OSStatus)deletePasswordFromKeychainForKey:(NSString *)key {
    const char *service = "QSSocialBookmarks";
    const char *account = [key UTF8String];
    
    SecKeychainItemRef item = NULL;
    OSStatus findStatus = SecKeychainFindGenericPassword(NULL,
                                                       (UInt32)strlen(service), service,
                                                       (UInt32)strlen(account), account,
                                                       NULL, NULL,
                                                       &item);
    
    if (findStatus == errSecSuccess) {
        OSStatus deleteStatus = SecKeychainItemDelete(item);
        CFRelease(item);
        return deleteStatus;
    }
    
    return findStatus;
}

#pragma mark - Password Keychain Methods

- (void)loadPasswordFromKeychain {
    if (!self.selectedEntry || !self.selectedEntry.identifier) {
        self.internalPassword = nil;
        return;
    }
    
    NSString *keychainKey = [self keychainKeyForIdentifier:self.selectedEntry.identifier];
    [self setPassword: [self passwordFromKeychainForKey:keychainKey]];
}

- (void)savePasswordToKeychain {
    if (!self.selectedEntry || !self.selectedEntry.identifier || !self.internalPassword) {
        return;
    }
    
    NSString *keychainKey = [self keychainKeyForIdentifier:self.selectedEntry.identifier];
    OSStatus status = [self savePasswordToKeychainForKey:keychainKey password:self.internalPassword];
    
    if (status != errSecSuccess) {
        NSLog(@"Failed to save password to keychain for key: %@, status: %d", keychainKey, (int)status);
    }
}

#pragma mark - Password Property Accessors

- (NSString *)password {
    return self.internalPassword;
}

- (void)setPassword:(NSString *)password {
    self.internalPassword = password;
    
    // Save to keychain asynchronously
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self savePasswordToKeychain];
    });
}

#pragma mark - Host Visibility Control
- (BOOL) isHostVisible {
    return [SocialSiteHelper hasVariableHost:[self siteIndex]];
}
- (void)setIsHostVisible:(BOOL)isVisible { }

#pragma mark - Objects For Entry

- (NSArray *)objectsForEntry:(QSCatalogEntry *)theEntry {
  
    NSDictionary *settings = theEntry.sourceSettings;
  
    SocialSite site = [settings objectForKey:@"site"] != nil ? [[settings objectForKey:@"site"] integerValue] : SocialSiteDelicious;
    NSString *username = [settings objectForKey:@"username"];
    NSString *identifier = theEntry.identifier;
    NSString *keychainKey = [self keychainKeyForIdentifier:identifier];
    NSString *password = [self passwordFromKeychainForKey:keychainKey];
    NSString *host = [settings objectForKey:@"host"];
    BOOL includeTags = [settings objectForKey:@"includeTags"];
    
    QSBookmarkProviderFactory *factory = [QSBookmarkProviderFactory sharedFactory];
    id<QSBookmarkProvider> provider = [factory providerForSite:site username:username password:password host:host];
    
    if (!provider) {
        NSLog(@"No provider available for site %ld with username %@", (long)site, username);
        return @[];
    }
  
  return [provider fetchBookmarksForSite:site username:username password:password identifier:identifier host:host includeTags:includeTags];
}

- (NSArray *)objectsForTag:(NSString *)tag site:(SocialSite)site username:(NSString *)username identifier:(NSString *)identifier host:(NSString *)host {
  
  NSString *keychainKey = [self keychainKeyForIdentifier:identifier];
  NSString *password = [self passwordFromKeychainForKey:keychainKey];

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
  if (@available(macOS 11.0, *)) {
    NSImage *image = [NSImage imageWithSystemSymbolName:@"tag" accessibilityDescription:@"Bookmark"];
    [object setIcon:image];
  } else {
    [object setIcon:[[NSBundle bundleForClass:[self class]]imageNamed:@"bookmark_icon"]];
  }
}

// All our objects will have children. URLs will have tags, and tags will have URLs.
- (BOOL)objectHasChildren:(QSObject *) object { return YES; }

// This will receive a tag object. Tag objects will have the
// source configuration in the meta: source.username,
// source.site, source.host and source.identifier.
- (BOOL)loadChildrenForObject:(QSObject *)object {
  
  NSNumber *siteNumber = [object objectForMeta:@"source.site"];
  if (!siteNumber) {
    NSLog(@"The tag didn't have a valid site.");
    return NO;
  }
  
  SocialSite site = [siteNumber integerValue];
  
  NSString *username = [object objectForMeta:@"source.username"];
  if (!username) {
    NSLog(@"The tag didn't have a valid username.");
    return NO;
  }
  NSString *identifier = [object objectForMeta:@"source.identifier"];
  if (!identifier) {
    NSLog(@"The tag didn't have a valid identifier.");
    return NO;
  }

  NSString *host = [object objectForMeta:@"source.host"];
  if (site == SocialSiteLinkding && !host) {
    NSLog(@"The tag didn't have a host, and its site requires it.");
    return NO;
  }

  NSString *tag = [object objectForType:kTagType];
  if (!tag) {
    NSLog(@"We could not find a valid tag type.");
    return NO;
  }

  NSArray *children = [self objectsForTag:tag site:site username:username identifier:identifier host:host];
    [object setChildren:children];
    return YES;
}

@end
