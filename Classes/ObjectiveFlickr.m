//
// ObjectiveFlickr.m
//
// Copyright (c) 2007-2009 Lithoglyph Inc. All rights reserved.
//

#import "ObjectiveFlickr.h"
#import "OFUtilities.h"

// compatibility typedefs
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
typedef unsigned int NSUInteger;
#endif

@interface OFFlickrAPIContext (PrivateMethods)
- (NSString *)signedQueryFromArguments:(NSDictionary *)inArguments;
@end

#define kDEFAULT_FLICKR_REST_API_ENDPOINT   @"http://api.flickr.com/services/rest/"

@implementation OFFlickrAPIContext
- (void)dealloc
{
    [key release];
    [sharedSecret release];
    [authToken release];
    
    [RESTAPIEndpoint release];
    
    [super dealloc];
}

- (id)initWithAPIKey:(NSString *)inKey sharedSecret:(NSString *)inSharedSecret
{
    if (self = [super init]) {
        key = [inKey copy];
        sharedSecret = [inSharedSecret copy];
        
        RESTAPIEndpoint = kDEFAULT_FLICKR_REST_API_ENDPOINT;
    }
    return self;
}

- (void)setAuthToken:(NSString *)inAuthToken
{
    NSString *tmp = authToken;
    authToken = [inAuthToken copy];
    [tmp release];
}

- (NSString *)authToken
{
    return authToken;
}

- (void)setRESTAPIEndpoint:(NSString *)inEndpoint
{
    NSString *tmp = RESTAPIEndpoint;
    RESTAPIEndpoint = [inEndpoint copy];
    [tmp release];
}

- (NSString *)RESTAPIEndpoint
{
    return RESTAPIEndpoint;
}

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
@synthesize key;
@synthesize sharedSecret;
#endif
@end

@implementation OFFlickrAPIContext (PrivateMethods)
- (NSString *)signedQueryFromArguments:(NSDictionary *)inArguments
{
    NSMutableDictionary *newArgs = [NSMutableDictionary dictionaryWithDictionary:inArguments];
	if ([key length]) {
		[newArgs setObject:key forKey:@"api_key"];
	}
	
	if ([authToken length]) {
		[newArgs setObject:key forKey:@"auth_token"];
	}
	
	// combine the args
#warning Check old code to see if it's unescaped
	NSMutableArray *argArray = [NSMutableArray array];
	NSMutableString *sigString = [NSMutableString stringWithString:[sharedSecret length] ? sharedSecret : @""];
	NSArray *sortedArgs = [[newArgs allKeys] sortedArrayUsingSelector:@selector(compare:)];
	NSEnumerator *argEnumerator = [sortedArgs objectEnumerator];
	NSString *nextKey;
	while (nextKey = [argEnumerator nextObject]) {
		NSString *value = [newArgs objectForKey:nextKey];
		[sigString appendFormat:@"%@%@", nextKey, value];
		[argArray addObject:[NSString stringWithFormat:@"%@=%@", nextKey, OFEscapedURLStringFromNSString(value)]];
	}
	
	NSString *signature = OFMD5HexStringFromNSString(sigString);
	[argArray addObject:[NSString stringWithFormat:@"%@=%@", @"api_sig", signature]];
	return [argArray componentsJoinedByString:@"&"];
}
@end

@implementation OFFlickrAPIRequest
- (void)dealloc
{
    [context release];
    [HTTPRequest release];
    [super dealloc];
}

- (id)initWithAPIContext:(OFFlickrAPIContext *)inContext
{
    if (self = [super init]) {
        context = [inContext retain];
        
        HTTPRequest = [[LFHTTPRequest alloc] init];
        [HTTPRequest setDelegate:self];        
    }
    
    return self;
}

- (OFFlickrAPIRequestDelegateType)delegate
{
    return delegate;
}

- (void)setDelegate:(OFFlickrAPIRequestDelegateType)inDelegate
{
    delegate = inDelegate;
}

- (NSTimeInterval)requestTimeoutInterval
{
    return [HTTPRequest timeoutInterval];
}

- (void)setRequestTimeoutInterval:(NSTimeInterval)inTimeInterval
{
    [HTTPRequest setTimeoutInterval:inTimeInterval];
}

- (BOOL)isRunning
{
    return [HTTPRequest isRunning];
}

- (void)cancel
{
    [HTTPRequest cancelWithoutDelegateMessage];
}

- (BOOL)callAPIMethodWithGET:(NSString *)inMethodName arguments:(NSDictionary *)inArguments
{
    // combine the parameters
 
	NSMutableDictionary *newArgs = [NSMutableDictionary dictionaryWithDictionary:inArguments];
	[newArgs setObject:inMethodName forKey:@"method"];
	
	NSString *query = [context signedQueryFromArguments:newArgs];
	NSLog(@"query = %@", query);
	
	NSString *URLString = [NSString stringWithFormat:@"%@?%@", [context RESTAPIEndpoint], query];
	NSLog(@"URL = %@", URLString);
	
	return NO;
}

#pragma mark LFHTTPRequest delegate methods
- (void)httpRequestDidComplete:(LFHTTPRequest *)request
{
    if ([delegate respondsToSelector:@selector(flickrAPIRequest:didCompleteWithResponse:)]) {
    }    
}

- (void)httpRequest:(LFHTTPRequest *)request didFailWithError:(NSString *)error
{
    NSError *toDelegateError = nil;
    if ([error isEqualToString:LFHTTPRequestConnectionError]) {
        // OFFlickrAPIRequestConnectionError = 1,
        

        
    }
    else if ([error isEqualToString:LFHTTPRequestTimeoutError]) {
        // OFFlickrAPIRequestTimeoutError = 2,
    }
    else {
        // OFFlickrAPIRequestUnknownError = 42
        
    }
    
    // - (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)error;
    
    if ([delegate respondsToSelector:@selector(flickrAPIRequest:didFailWithError:)]) {
        [delegate flickrAPIRequest:self didFailWithError:toDelegateError];        
    }
}

- (void)httpRequest:(LFHTTPRequest *)request receivedBytes:(NSUInteger)bytesReceived expectedTotal:(NSUInteger)total
{   
}

- (void)httpRequest:(LFHTTPRequest *)request sentBytes:(NSUInteger)bytesSent total:(NSUInteger)total
{
}
@end
