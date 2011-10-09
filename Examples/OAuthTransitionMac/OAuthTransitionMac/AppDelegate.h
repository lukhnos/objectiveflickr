//
//  AppDelegate.h
//  OAuthTransitionMac
//
//  Created by Lukhnos D. Liu on 10/9/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ObjectiveFlickr/ObjectiveFlickr.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, OFFlickrAPIRequestDelegate>
{
    OFFlickrAPIContext *_flickrContext;
    OFFlickrAPIRequest *_flickrRequest;
    
    NSString *_frob;
}
@property (assign) IBOutlet NSWindow *window;

@property (assign) IBOutlet NSButton *oauthAuthButton;
@property (assign) IBOutlet NSButton *oldStyleAuthButton;
@property (assign) IBOutlet NSButton *testLoginButton;
@property (assign) IBOutlet NSButton *upgradeTokenButton;
@property (assign) IBOutlet NSTextField *progressLabel;
@property (assign) IBOutlet NSProgressIndicator *progressIndicator;

- (IBAction)oldStyleAuthentication:(id)sender;
- (IBAction)oauthAuthenticationAction:(id)sender;
- (IBAction)testLoginAction:(id)sender;
- (IBAction)upgradeTokenAction:(id)sender;

@end
