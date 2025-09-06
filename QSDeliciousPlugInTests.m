//
//  QSDeliciousPlugInTests.m
//  QSDeliciousPlugIn
//

#import <Testing/Testing.h>
#import "QSBookmarkProviderFactory.h"
#import "QSDeliciousAPIProvider.h"
#import "QSLinkdingProvider.h"
#import "SocialSite.h"

@suite("QSDeliciousPlugIn Strategy Pattern Tests")
struct QSDeliciousPlugInTests {
    
    @Test("Factory returns correct provider for Delicious")
    func testDeliciousProvider() async throws {
        QSBookmarkProviderFactory *factory = [QSBookmarkProviderFactory sharedFactory];
        
        id<QSBookmarkProvider> provider = [factory providerForSite:SocialSiteDelicious 
                                                           username:@"testuser" 
                                                           password:@"testpass" 
                                                               host:nil];
        
        #expect(provider != nil, "Should return a provider for Delicious");
        #expect([provider isKindOfClass:[QSDeliciousAPIProvider class]], "Should return a QSDeliciousAPIProvider for Delicious");
        #expect([provider supportedSite] == SocialSiteDelicious, "Provider should support Delicious site");
    }
    
    @Test("Factory returns correct provider for Pinboard")
    func testPinboardProvider() async throws {
        QSBookmarkProviderFactory *factory = [QSBookmarkProviderFactory sharedFactory];
        
        id<QSBookmarkProvider> provider = [factory providerForSite:SocialSitePinboard 
                                                           username:@"testuser" 
                                                           password:@"testpass" 
                                                               host:nil];
        
        #expect(provider != nil, "Should return a provider for Pinboard");
        #expect([provider isKindOfClass:[QSDeliciousAPIProvider class]], "Should return a QSDeliciousAPIProvider for Pinboard");
        #expect([provider supportedSite] == SocialSitePinboard, "Provider should support Pinboard site");
    }
    
    @Test("Factory returns correct provider for Linkding")
    func testLinkdingProvider() async throws {
        QSBookmarkProviderFactory *factory = [QSBookmarkProviderFactory sharedFactory];
        
        id<QSBookmarkProvider> provider = [factory providerForSite:SocialSiteLinkding 
                                                           username:@"testuser" 
                                                           password:@"testtoken" 
                                                               host:@"https://bookmarks.example.com"];
        
        #expect(provider != nil, "Should return a provider for Linkding");
        #expect([provider isKindOfClass:[QSLinkdingProvider class]], "Should return a QSLinkdingProvider for Linkding");
        #expect([provider supportedSite] == SocialSiteLinkding, "Provider should support Linkding site");
    }
    
    @Test("Factory returns nil for invalid configuration")
    func testInvalidConfiguration() async throws {
        QSBookmarkProviderFactory *factory = [QSBookmarkProviderFactory sharedFactory];
        
        // Test with empty username
        id<QSBookmarkProvider> provider = [factory providerForSite:SocialSiteDelicious 
                                                           username:@"" 
                                                           password:@"testpass" 
                                                               host:nil];
        
        #expect(provider == nil, "Should return nil for empty username");
        
        // Test Linkding without host
        provider = [factory providerForSite:SocialSiteLinkding 
                                   username:@"testuser" 
                                   password:@"testtoken" 
                                       host:@""];
        
        #expect(provider == nil, "Should return nil for Linkding without host");
    }
    
    @Test("SocialSite helper methods work correctly")
    func testSocialSiteHelpers() async throws {
        #expect([[SocialSiteHelper displayNameForSite:SocialSiteDelicious] isEqualToString:@"del.icio.us"]);
        #expect([[SocialSiteHelper displayNameForSite:SocialSiteLinkding] isEqualToString:@"Linkding"]);
        
        #expect([[SocialSiteHelper siteURLForSite:SocialSitePinboard] isEqualToString:@"pinboard.in"]);
        #expect([[SocialSiteHelper siteURLForSite:SocialSiteLinkding] isEqualToString:@""]);
        
        #expect([[SocialSiteHelper reversedSiteURLForSite:SocialSiteDelicious] isEqualToString:@"us.icio.del"]);
        #expect([[SocialSiteHelper reversedSiteURLForSite:SocialSiteLinkding] isEqualToString:@"linkding"]);
    }
}
