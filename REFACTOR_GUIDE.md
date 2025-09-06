# QSDeliciousPlugIn Refactor Guide

This document outlines the refactoring changes made to support multiple social bookmark providers using the Strategy Pattern.

## Overview

The plugin has been refactored from a monolithic implementation to a modular, extensible architecture that makes it easy to add new bookmark providers.

## Architecture

### Core Components

1. **SocialSite Enum** (`SocialSite.h/.m`)
   - Defines supported bookmark services
   - Helper methods for display names and URLs

2. **QSBookmarkProvider Protocol** (`QSBookmarkProvider.h`)
   - Defines the interface all providers must implement
   - Key methods: `canHandleSite:username:password:host:`, `fetchBookmarksForSite:username:password:host:includeTags:`

3. **QSBookmarkProviderFactory** (`QSBookmarkProviderFactory.h/.m`)
   - Singleton factory that manages all providers
   - Returns the appropriate provider for a given configuration

4. **Provider Implementations**
   - `QSDeliciousAPIProvider`: Handles XML-based Delicious / Pinboard v1 API (Delicious, Magnolia, Pinboard)
   - `QSLinkdingProvider`: Handles JSON-based Linkding API

### Strategy Pattern Implementation

The main source file now uses the strategy pattern:

```objective-c
// Get the appropriate provider using the factory
QSBookmarkProviderFactory *factory = [QSBookmarkProviderFactory sharedFactory];
id<QSBookmarkProvider> provider = [factory providerForSite:site username:username password:password host:host];

if (!provider) {
    NSLog(@"No provider available for site %ld with username %@", (long)site, username);
    return @[];
}

return [provider fetchBookmarksForSite:site username:username password:password host:host includeTags:includeTags];
```

## Supported Services

| Service | ID | API Type | Authentication | Host Required |
|---------|----|---------| -------------- | ------------- |
| del.icio.us | 0 | XML/Basic Auth | Username/Password | No |
| ma.gnolia.com | 1 | XML/Basic Auth | Username/Password | No |
| Pinboard | 2 | XML/Basic Auth | Username/Password | No |
| Linkding | 3 | JSON/Token Auth | Username/API Token | Yes |

## Adding New Providers

1. Add a new case to the `SocialSite` enum
2. Update `SocialSiteHelper` methods
3. Create a new provider class implementing `QSBookmarkProvider`
4. Add the provider to `QSBookmarkProviderFactory.setupProviders`

Example new provider structure:

```objective-c
@interface QSMyNewProvider : NSObject <QSBookmarkProvider>
@end

@implementation QSMyNewProvider

- (BOOL)canHandleSite:(SocialSite)site username:(NSString *)username password:(NSString *)password host:(NSString *)host {
    return (site == SocialSiteMyNew) && username.length > 0 && password.length > 0;
}

- (NSArray *)fetchBookmarksForSite:(SocialSite)site username:(NSString *)username password:(NSString *)password host:(NSString *)host includeTags:(BOOL)includeTags {
    // Implementation here
}

// ... other required methods
@end
```

## Interface Bindings

The NIB file should be updated to include:

- **Settings Dictionary** with keys:
  - `username` (NSString)
  - `password` (NSString) - bound to File's Owner directly
  - `site` (NSInteger) - SocialSite enum value
  - `host` (NSString) - required for Linkding, optional for others
  - `includeTags` (BOOL)

## Migration from Old Code

The original `QSDeliciousPlugIn_Source.m` has been refactored into `QSDeliciousPlugIn_Source_New.m`. Key changes:

1. Removed hardcoded site logic
2. Removed XML parsing from main class (moved to providers)
3. Added strategy pattern implementation
4. Added support for custom hosts (Linkding)
5. Simplified the main object fetching logic

## Testing

Tests are included in `QSDeliciousPlugInTests.m` using Swift Testing framework:
- Factory provider selection tests
- Configuration validation tests
- Helper method tests

## Linkding Configuration

For Linkding users:
1. Set Site to "Linkding" (value 3)
2. Enter your Linkding server URL in the Host field (e.g., `https://bookmarks.example.com`)
3. Use your API Token as the Password
4. Enter your username (though it's mainly for caching purposes in Linkding)

The Linkding provider will automatically handle URL construction and JSON parsing.
