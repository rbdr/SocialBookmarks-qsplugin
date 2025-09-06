//
//  QSDeliciousPlugIn_Source.h
//  QSDeliciousPlugIn
//
//  Created by Nicholas Jitkoff on 9/18/04.
//  Copyright __MyCompanyName__ 2004. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QSCore/QSCore.h>
#import "SocialSite.h"
#import "QSBookmarkProvider.h"
#import "QSBookmarkProviderFactory.h"

@interface QSDeliciousPlugIn_Source : QSObjectSource {
  IBOutlet NSTextField *userField;
  IBOutlet NSTextField *passField;
  IBOutlet NSTextField *hostField;
}
@end

@interface QSCatalogEntry (OldStyleSourceSupport)
@property NSMutableDictionary *info;
- (id)objectForKey:(NSString *)key;
@end
