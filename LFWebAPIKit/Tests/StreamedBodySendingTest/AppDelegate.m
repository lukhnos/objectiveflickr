//
// AppDelegate.m
//
// Copyright (c) 2007-2009 Lithoglyph Inc. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate
- (void)dealloc
{
    [HTTPServer stop];
    [HTTPServer release];
    [HTTPRequest release];
    [randomData release];
    [super dealloc];
}

- (void)awakeFromNib
{
    HTTPServer = [[GTMHTTPServer alloc] initWithDelegate:self];
    HTTPRequest = [[LFHTTPRequest alloc] init];
    [HTTPRequest setDelegate:self];
    
    NSError *error;
    [HTTPServer setPort:25642];
    [HTTPServer start:&error];
    
    NSAssert(!error, @"Server must start");
    [messageText setStringValue:@"Server started at port 25642, press button to test"];
}
- (IBAction)testButtonAction:(id)sender
{
    if (randomData) {
        [randomData release];
    }
    
    randomData = [[NSMutableData dataWithLength:1024 * 1024] retain];
    uint8_t *bytes = [randomData mutableBytes];
    size_t i;
    for (i = 0 ; i < 1024 * 1024 ; i++) {
        bytes[i] = 0x80;
    }
    
    NSInputStream *inputStream = [NSInputStream inputStreamWithData:randomData];                                
    [HTTPRequest performMethod:LFHTTPRequestPOSTMethod onURL:[NSURL URLWithString:@"http://localhost:25642"] withInputStream:inputStream knownContentSize:[randomData length]];
}

- (GTMHTTPResponseMessage *)httpServer:(GTMHTTPServer *)server handleRequest:(GTMHTTPRequestMessage *)request
{
    NSLog(@"%s %lu", __PRETTY_FUNCTION__, [[request body] length]);
    return [GTMHTTPResponseMessage responseWithHTMLString:@"<b>Hello</b>, world!"];
}

- (void)httpRequestDidComplete:(LFHTTPRequest *)request
{
    NSLog(@"%s %@", __PRETTY_FUNCTION__, [request receivedData]);
}

- (void)httpRequest:(LFHTTPRequest *)request didFailWithError:(NSString *)error
{
    NSLog(@"%s %@", __PRETTY_FUNCTION__, error);
}

@end
