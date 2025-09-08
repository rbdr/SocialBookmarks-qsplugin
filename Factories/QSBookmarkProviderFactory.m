//
//  QSBookmarkProviderFactory.m
//  QSDeliciousPlugIn
//

#import "QSBookmarkProviderFactory.h"
#import "QSDeliciousAPIProvider.h"
#import "QSLinkdingProvider.h"
#import "SocialSite.h"

@interface QSBookmarkProviderFactory ()
@property (nonatomic, strong, readwrite) NSArray<id<QSBookmarkProvider>> *providers;
@end

@implementation QSBookmarkProviderFactory

+ (instancetype)sharedFactory {
    static QSBookmarkProviderFactory *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupProviders];
    }
    return self;
}

- (void)setupProviders {
    NSMutableArray *mutableProviders = [NSMutableArray array];
    
    // Create Delicious / Pinboard API providers for each supported site
    QSDeliciousAPIProvider *deliciousAPIProvider = [[QSDeliciousAPIProvider alloc] init];
    
    // Create Linkding provider
    QSLinkdingProvider *linkdingProvider = [[QSLinkdingProvider alloc] init];
    
    [mutableProviders addObject:deliciousAPIProvider];
    [mutableProviders addObject:linkdingProvider];
    
    self.providers = [mutableProviders copy];
}

- (id<QSBookmarkProvider>)providerForSite:(SocialSite)site username:(NSString *)username password:(NSString *)password host:(NSString *)host {
    for (id<QSBookmarkProvider> provider in self.providers) {
        if ([provider canHandleSite:site username:username password:password host:host]) {
            return provider;
        }
    }
    return nil;
}

- (NSArray<id<QSBookmarkProvider>> *)allProviders {
    return self.providers;
}

@end
