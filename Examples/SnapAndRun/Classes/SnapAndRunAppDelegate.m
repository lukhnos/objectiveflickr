//
// SnapAndRunAppDelegate.m
//
// Copyright (c) 2009 Lukhnos D. Liu (http://lukhnos.org)
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

#import "SnapAndRunAppDelegate.h"
#import "SnapAndRunViewController.h"
#import "SampleAPIKey.h"

// preferably, the auth token is stored in the keychain, but since working with keychain is a pain, we use the simpler default system
NSString *kStoredAuthTokenKeyName = @"FlickrAuthToken";

@implementation SnapAndRunAppDelegate
- (void)dealloc
{
    [viewController release];
    [window release];
    [flickrContext release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	// query has the form of "&frob=", the rest is the frob
	NSString *frob = [[url query] substringFromIndex:6];
	
	OFFlickrAPIRequest *request = [[OFFlickrAPIRequest alloc] initWithAPIContext:self.flickrContext];
	request.delegate = self;
	[request callAPIMethodWithGET:@"flickr.auth.getToken" arguments:[NSDictionary dictionaryWithObjectsAndKeys:frob, @"frob", nil]];
    return YES;
}
        
- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];
}

+ (SnapAndRunAppDelegate *)sharedDelegate
{
    return (SnapAndRunAppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (void)setAndStoreFlickrAuthToken:(NSString *)inAuthToken
{
    NSAssert([inAuthToken length], @"Auth token cannot be empty");
    self.flickrContext.authToken = inAuthToken;
    [[NSUserDefaults standardUserDefaults] setObject:inAuthToken forKey:kStoredAuthTokenKeyName];
}

- (OFFlickrAPIContext *)flickrContext
{
    if (!flickrContext) {
        flickrContext = [[OFFlickrAPIContext alloc] initWithAPIKey:OBJECTIVE_FLICKR_SAMPLE_API_KEY sharedSecret:OBJECTIVE_FLICKR_SAMPLE_API_SHARED_SECRET];
        
        NSString *authToken;
        if (authToken = [[NSUserDefaults standardUserDefaults] objectForKey:kStoredAuthTokenKeyName]) {
            flickrContext.authToken = authToken;
        }
    }
    
    return flickrContext;
}

#pragma mark OFFlickrAPIRequest delegate methods
- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary
{
	[self setAndStoreFlickrAuthToken:[[inResponseDictionary valueForKeyPath:@"auth.token"] textContent]];
	[[[[UIAlertView alloc] initWithTitle:@"Has Token" message:self.flickrContext.authToken delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] autorelease] show];
	
	[inRequest autorelease];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)inError
{
	[[[[UIAlertView alloc] initWithTitle:@"Failed" message:[inError description] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] autorelease] show];	

	[inRequest autorelease];
}

@synthesize viewController;
@synthesize window;
@synthesize flickrContext;
@end
