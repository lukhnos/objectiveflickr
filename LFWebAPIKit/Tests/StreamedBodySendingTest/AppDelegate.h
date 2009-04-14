//
// AppDelegate.h
//
// Copyright (c) 2007-2009 Lithoglyph Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GTMHTTPServer.h"
#import "LFHTTPRequest.h"

@interface AppDelegate : NSObject
{
    IBOutlet NSTextField *messageText;
    
    GTMHTTPServer *HTTPServer;
    LFHTTPRequest *HTTPRequest;
    NSMutableData *randomData;
}
- (IBAction)testButtonAction:(id)sender;
@end
