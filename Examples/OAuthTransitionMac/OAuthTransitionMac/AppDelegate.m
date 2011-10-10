//
//  AppDelegate.m
//  OAuthTransitionMac
//
//  Created by Lukhnos D. Liu on 10/9/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "SampleAPIKey.h"


static NSString *kCallbackURLBaseString = @"oatransdemo://callback";
static NSString *kOAuthAuth = @"OAuth";
static NSString *kFrobRequest = @"Frob";
static NSString *kTryObtainAuthToken = @"TryAuth";
static NSString *kTestLogin = @"TestLogin";
static NSString *kUpgradeToken = @"UpgradeToken";

const NSTimeInterval kTryObtainAuthTokenInterval = 3.0;

@implementation AppDelegate
@synthesize oldStyleAuthButton = _oldStyleAuthButton;
@synthesize oauthAuthButton = _oauthAuthButton;
@synthesize testLoginButton = _testLoginButton;
@synthesize upgradeTokenButton = _upgradeTokenButton;
@synthesize progressLabel = _progressLabel;
@synthesize progressIndicator = _progressIndicator;
@synthesize window = _window;




- (void)handleIncomingURL:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSURL *callbackURL = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
    NSLog(@"Callback URL: %@", [callbackURL absoluteString]);
    
    NSString *requestToken= nil;
    NSString *verifier = nil;
    
    BOOL result = OFExtractOAuthCallback(callbackURL, [NSURL URLWithString:kCallbackURLBaseString], &requestToken, &verifier);
    if (!result) {
        NSLog(@"Invalid callback URL");
    }
              
    [_flickrRequest fetchOAuthAccessTokenWithRequestToken:requestToken verifier:verifier];
}
              


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleIncomingURL:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];    
    
    
    _flickrContext = [[OFFlickrAPIContext alloc] initWithAPIKey:OBJECTIVE_FLICKR_SAMPLE_API_KEY sharedSecret:OBJECTIVE_FLICKR_SAMPLE_API_SHARED_SECRET];
    
    _flickrRequest = [[OFFlickrAPIRequest alloc] initWithAPIContext:_flickrContext];
    _flickrRequest.delegate = self;
    _flickrRequest.requestTimeoutInterval = 60.0;
}

- (IBAction)oldStyleAuthentication:(id)sender
{
    [_progressIndicator startAnimation:self];
    [_progressLabel setStringValue:@"Starting old-style authentication..."];
    
    _flickrRequest.sessionInfo = kFrobRequest;
    [_flickrRequest callAPIMethodWithGET:@"flickr.auth.getFrob" arguments:nil];
    [_oauthAuthButton setEnabled:NO];
    [_oldStyleAuthButton setEnabled:NO];
}

- (IBAction)oauthAuthenticationAction:(id)sender
{
    [_progressIndicator startAnimation:self];
    [_progressLabel setStringValue:@"Starting OAuth authentication..."];

    _flickrRequest.sessionInfo = kOAuthAuth;
    [_flickrRequest fetchOAuthRequestTokenWithCallbackURL:[NSURL URLWithString:kCallbackURLBaseString]];
    [_oldStyleAuthButton setEnabled:NO];
    [_oauthAuthButton setEnabled:NO];
}

- (IBAction)testLoginAction:(id)sender
{
    if (_flickrContext.OAuthToken || _flickrContext.authToken) {
        _flickrRequest.sessionInfo = kTestLogin;
        [_flickrRequest callAPIMethodWithGET:@"flickr.test.login" arguments:nil];
        [_progressLabel setStringValue:@"Calling flickr.test.login..."];

        
        // this tests flickr.photos.getInfo
        /*
         NSString *somePhotoID = @"42";        
         [_flickrRequest callAPIMethodWithGET:@"flickr.photos.getInfo" arguments:[NSDictionary dictionaryWithObjectsAndKeys:somePhotoID, @"photo_id", nil]];
         [_progressLabel setStringValue:@"Calling flickr.photos.getInfo..."];

         */
        
        
        // this tests flickr.photos.setMeta, a method that requires POST
        /*
         NSString *somePhotoID = @"42";
         NSString *someTitle = @"Lorem iprum!";
         NSString *someDesc = @"^^ :)";
         NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                somePhotoID, @"photo_id", 
                                someTitle, @"title",
                                someDesc, @"description",
                                nil];
         [_flickrRequest callAPIMethodWithPOST:@"flickr.photos.setMeta" arguments:params];
         [_progressLabel setStringValue:@"Calling flickr.photos.setMeta..."];

         */
        
         
        // test photo uploading
        /*
         NSString *somePath = @"/tmp/test.png";
         NSString *someFilename = @"Foo.png";
         NSString *someTitle = @"Lorem iprum!";
         NSString *someDesc = @"^^ :)";
         NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                someTitle, @"title",
                                someDesc, @"description",
                                nil];        
         [_flickrRequest uploadImageStream:[NSInputStream inputStreamWithFileAtPath:somePath] suggestedFilename:someFilename MIMEType:@"image/png" arguments:params];
         [_progressLabel setStringValue:@"Uploading photos..."];
        */
        
        [_progressIndicator startAnimation:self];
        [_progressLabel setStringValue:@"Calling flickr.test.login..."];
        [_testLoginButton setEnabled:NO];
    }
    else {
        NSRunAlertPanel(@"No Auth Token", @"Please authenticate first", @"Dismiss", nil, nil);
    }
}

- (IBAction)upgradeTokenAction:(id)sender
{
    if (_flickrContext.OAuthToken) {
        NSRunAlertPanel(@"Already Using OAuth", @"There's no need to upgrade to token", @"Dismiss", nil, nil);
    }
    else {
        _flickrRequest.sessionInfo = kUpgradeToken;
        [_flickrRequest callAPIMethodWithGET:@"flickr.auth.oauth.getAccessToken" arguments:nil];
        [_upgradeTokenButton setEnabled:NO];
    }
}

- (void)tryObtainAuthToken
{
    _flickrRequest.sessionInfo = kTryObtainAuthToken;
    [_flickrRequest callAPIMethodWithGET:@"flickr.auth.getToken" arguments:[NSDictionary dictionaryWithObjectsAndKeys:_frob, @"frob", nil]];
}


- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthRequestToken:(NSString *)inRequestToken secret:(NSString *)inSecret;
{
    _flickrContext.OAuthToken = inRequestToken;
    _flickrContext.OAuthTokenSecret = inSecret;
    
    NSURL *authURL = [_flickrContext userAuthorizationURLWithRequestToken:inRequestToken requestedPermission:OFFlickrWritePermission];
    NSLog(@"Auth URL: %@", [authURL absoluteString]);
    [[NSWorkspace sharedWorkspace] openURL:authURL];
    
    [_progressLabel setStringValue:@"Waiting fo user authentication (OAuth)..."];    
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthAccessToken:(NSString *)inAccessToken secret:(NSString *)inSecret userFullName:(NSString *)inFullName userName:(NSString *)inUserName userNSID:(NSString *)inNSID
{
    _flickrContext.OAuthToken = inAccessToken;
    _flickrContext.OAuthTokenSecret = inSecret;

    NSLog(@"Token: %@, secret: %@", inAccessToken, inSecret);    
    
    [_progressLabel setStringValue:@"Authenticated"];
    [_progressIndicator stopAnimation:self];
    [_testLoginButton setEnabled:YES];
    NSRunAlertPanel(@"Authenticated", [NSString stringWithFormat:@"OAuth access token: %@, secret: %@", inAccessToken, inSecret], @"Dismiss", nil, nil);
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary
{
    NSLog(@"%s, return: %@", __PRETTY_FUNCTION__, inResponseDictionary);
    
    [_progressIndicator stopAnimation:self];
    [_progressLabel setStringValue:@"API call succeeded"];
    
    if (inRequest.sessionInfo == kFrobRequest) {
        _frob = [[inResponseDictionary valueForKeyPath:@"frob._text"] copy];
        NSLog(@"%@: %@", kFrobRequest, _frob);
        
        NSURL *authURL = [_flickrContext loginURLFromFrobDictionary:inResponseDictionary requestedPermission:OFFlickrWritePermission];
        [[NSWorkspace sharedWorkspace] openURL:authURL];
        
        [self performSelector:@selector(tryObtainAuthToken) withObject:nil afterDelay:kTryObtainAuthTokenInterval];
        
        [_progressIndicator startAnimation:self];
        [_progressLabel setStringValue:@"Waiting for user authentication..."];
    }
    else if (inRequest.sessionInfo == kTryObtainAuthToken) {
        NSString *authToken = [inResponseDictionary valueForKeyPath:@"auth.token._text"];
        NSLog(@"%@: %@", kTryObtainAuthToken, authToken);
        
        _flickrContext.authToken = authToken;
        _flickrRequest.sessionInfo = nil;
        
        [_upgradeTokenButton setEnabled:YES];
        [_testLoginButton setEnabled:YES];
    }
    else if (inRequest.sessionInfo == kUpgradeToken) {
        NSString *oat = [inResponseDictionary valueForKeyPath:@"auth.access_token.oauth_token"];
        NSString *oats = [inResponseDictionary valueForKeyPath:@"auth.access_token.oauth_token_secret"];
        
        _flickrContext.authToken = nil;
        _flickrContext.OAuthToken = oat;
        _flickrContext.OAuthTokenSecret = oats;
        NSRunAlertPanel(@"Auth Token Upgraded", [NSString stringWithFormat:@"New OAuth token: %@, secret: %@", oat, oats], @"Dismiss", nil, nil);
        
        [_oldStyleAuthButton setEnabled:NO];
        [_upgradeTokenButton setEnabled:NO];
    }
    else if (inRequest.sessionInfo == kTestLogin) {
        _flickrRequest.sessionInfo = nil;
        [_testLoginButton setEnabled:YES];
        NSRunAlertPanel(@"Test OK!", @"API returns successfully", @"Dismiss", nil, nil);
    }
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)inError
{
    NSLog(@"%s, error: %@", __PRETTY_FUNCTION__, inError);
    
    if (inRequest.sessionInfo == kTryObtainAuthToken) {
        [self performSelector:@selector(tryObtainAuthToken) withObject:nil afterDelay:kTryObtainAuthTokenInterval];        
    }
    else {
        if (inRequest.sessionInfo == kOAuthAuth || inRequest.sessionInfo == kFrobRequest || inRequest.sessionInfo == kTryObtainAuthToken) {
            [_oldStyleAuthButton setEnabled:YES];
            [_oauthAuthButton setEnabled:YES];
            [_testLoginButton setEnabled:NO];
            [_upgradeTokenButton setEnabled:NO];
        }
        else if (inRequest.sessionInfo == kUpgradeToken) {
            [_upgradeTokenButton setEnabled:YES];
        }
        else if (inRequest.sessionInfo == kTestLogin) {
            [_testLoginButton setEnabled:YES];
        }
        
        [_progressIndicator stopAnimation:self];
        [_progressLabel setStringValue:@"Error"];
        NSRunAlertPanel(@"API Error", [NSString stringWithFormat:@"An error occurred in the stage \"%@\", error: %@", inRequest.sessionInfo, inError], @"Dismiss", nil, nil);
    }
}


- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest imageUploadSentBytes:(NSUInteger)inSentBytes totalBytes:(NSUInteger)inTotalBytes
{
    NSLog(@"%s %lu/%lu", __PRETTY_FUNCTION__, inSentBytes, inTotalBytes);
}
@end
