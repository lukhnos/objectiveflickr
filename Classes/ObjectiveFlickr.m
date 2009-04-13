//
// ObjectiveFlickr.m
//
// Copyright (c) 2007-2009 Lithoglyph Inc. All rights reserved.
//

#import "ObjectiveFlickr.h"
#import "OFUtilities.h"
#import "OFXMLMapper.h"

NSString *OFFlickrAPIReturnedErrorDomain = @"com.flickr";
NSString *OFFlickrAPIRequestErrorDomain = @"org.lukhnos.ObjectiveFlickr";

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
	NSString *URLString = [NSString stringWithFormat:@"%@?%@", [context RESTAPIEndpoint], query];
	
	return [HTTPRequest performMethod:LFHTTPRequestGETMethod onURL:[NSURL URLWithString:URLString] withData:nil];
}

#pragma mark LFHTTPRequest delegate methods
- (void)httpRequestDidComplete:(LFHTTPRequest *)request
{
	NSDictionary *responseDictionary = [OFXMLMapper dictionaryMappedFromXMLData:[request receivedData]];	
	NSDictionary *rsp = [responseDictionary objectForKey:@"rsp"];
	NSString *stat = [rsp objectForKey:@"stat"];
	
	// this also fails when (responseDictionary, rsp, stat) == nil, so it's a guranteed way of checking the result
	if (![stat isEqualToString:@"ok"]) {
		NSDictionary *err = [rsp objectForKey:@"err"];
		NSString *code = [err objectForKey:@"code"];
		NSString *msg = [err objectForKey:@"msg"];
	
		NSError *toDelegateError;
		if ([code length]) {
			// intValue for 10.4-compatibility
			toDelegateError = [NSError errorWithDomain:OFFlickrAPIReturnedErrorDomain code:[code intValue] userInfo:[msg length] ? [NSDictionary dictionaryWithObjectsAndKeys:msg, NSLocalizedFailureReasonErrorKey, nil] : nil];				
		}
		else {
			toDelegateError = [NSError errorWithDomain:OFFlickrAPIRequestErrorDomain code:OFFlickrAPIRequestFaultyXMLResponseError userInfo:nil];
		}
			
		if ([delegate respondsToSelector:@selector(flickrAPIRequest:didFailWithError:)]) {
			[delegate flickrAPIRequest:self didFailWithError:toDelegateError];        
		}
		return;
	}
	
    if ([delegate respondsToSelector:@selector(flickrAPIRequest:didCompleteWithResponse:)]) {
		[delegate flickrAPIRequest:self didCompleteWithResponse:rsp];
    }    
}

- (void)httpRequest:(LFHTTPRequest *)request didFailWithError:(NSString *)error
{
    NSError *toDelegateError = nil;
    if ([error isEqualToString:LFHTTPRequestConnectionError]) {
		toDelegateError = [NSError errorWithDomain:OFFlickrAPIRequestErrorDomain code:OFFlickrAPIRequestConnectionError userInfo:nil];
    }
    else if ([error isEqualToString:LFHTTPRequestTimeoutError]) {
		toDelegateError = [NSError errorWithDomain:OFFlickrAPIRequestErrorDomain code:OFFlickrAPIRequestTimeoutError userInfo:nil];
    }
    else {
		toDelegateError = [NSError errorWithDomain:OFFlickrAPIRequestErrorDomain code:OFFlickrAPIRequestUnknownError userInfo:nil];
    }
    
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
