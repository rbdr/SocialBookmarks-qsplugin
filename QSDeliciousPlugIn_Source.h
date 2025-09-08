//
//  QSDeliciousPlugIn_Source.h
//  QSDeliciousPlugIn
//
//  Created by Nicholas Jitkoff on 9/18/04.
//  Copyright __MyCompanyName__ 2004. All rights reserved.
//

#import "QSBookmarkProvider.h"
#import "QSBookmarkProviderFactory.h"
#import "SocialSite.h"
#import <Foundation/Foundation.h>
#import <QSCore/QSCore.h>

@interface QSDeliciousPlugIn_Source : QSObjectSource {
  IBOutlet NSTextField *userField;
  IBOutlet NSTextField *passField;
  IBOutlet NSTextField *hostField;
}
@property(nonatomic, strong) NSString *internalPassword;

- (IBAction)settingsChanged:(id)sender;
@end

@interface QSCatalogEntry (OldStyleSourceSupport)
@property NSMutableDictionary *info;
- (id)objectForKey:(NSString *)key;
@end
