//
// ObjectiveFlickr.m
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

#import "ObjectiveFlickr.h"
#import "OFUtilities.h"
#import "OFXMLMapper.h"

NSString *OFFlickrSmallSquareSize = @"s";
NSString *OFFlickrThumbnailSize = @"t";
NSString *OFFlickrSmallSize = @"m";
NSString *OFFlickrMediumSize = nil;
NSString *OFFlickrLargeSize = @"b";

NSString *OFFlickrReadPermission = @"read";
NSString *OFFlickrWritePermission = @"write";
NSString *OFFlickrDeletePermission = @"delete";

NSString *OFFlickrAPIReturnedErrorDomain = @"com.flickr";
NSString *OFFlickrAPIRequestErrorDomain = @"org.lukhnos.ObjectiveFlickr";

// compatibility typedefs
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
typedef unsigned int NSUInteger;
#endif

@interface OFFlickrAPIContext (PrivateMethods)
- (NSString *)signedQueryFromArguments:(NSDictionary *)inArguments;
@end

#define kDefaultFlickrRESTAPIEndpoint   @"http://api.flickr.com/services/rest/"
#define kDefaultFlickrPhotoSource		@"http://static.flickr.com/"
#define kDefaultFlickrAuthEndpoint		@"http://flickr.com/services/auth/"

@implementation OFFlickrAPIContext
- (void)dealloc
{
    [key release];
    [sharedSecret release];
    [authToken release];
    
    [RESTAPIEndpoint release];
	[photoSource release];
	[authEndpoint release];
    
    [super dealloc];
}

- (id)initWithAPIKey:(NSString *)inKey sharedSecret:(NSString *)inSharedSecret
{
    if (self = [super init]) {
        key = [inKey copy];
        sharedSecret = [inSharedSecret copy];
        
        RESTAPIEndpoint = kDefaultFlickrRESTAPIEndpoint;
		photoSource = kDefaultFlickrPhotoSource;
		authEndpoint = kDefaultFlickrAuthEndpoint;
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

- (NSURL *)photoSourceURLFromDictionary:(NSDictionary *)inDictionary size:(NSString *)inSizeModifier
{
	// http://farm{farm-id}.static.flickr.com/{server-id}/{id}_{secret}_[mstb].jpg
	// http://farm{farm-id}.static.flickr.com/{server-id}/{id}_{secret}.jpg
	
	NSString *farm = [inDictionary objectForKey:@"farm"];
	NSString *photoID = [inDictionary objectForKey:@"id"];
	NSString *secret = [inDictionary objectForKey:@"secret"];
	NSString *server = [inDictionary objectForKey:@"server"];
	
	NSMutableString *URLString = [NSMutableString stringWithString:@"http://"];
	if ([farm length]) {
		[URLString appendFormat:@"farm%@.", farm];
	}
	
	// skips "http://"
	NSAssert([server length], @"Must have server attribute");
	NSAssert([photoID length], @"Must have id attribute");
	NSAssert([secret length], @"Must have secret attribute");
	[URLString appendString:[photoSource substringFromIndex:7]];
	[URLString appendFormat:@"%@/%@_%@", server, photoID, secret];
	
	if ([inSizeModifier length]) {
		[URLString appendFormat:@"_%@.jpg"];
	}
	else {
		[URLString appendString:@".jpg"];
	}
	
	return [NSURL URLWithString:URLString];
}

- (NSURL *)loginURLFromFrobDictionary:(NSDictionary *)inFrob requestedPermission:(NSString *)inPermission
{
	NSString *frob = [[inFrob objectForKey:@"frob"] objectForKey:OFXMLTextContentKey];
	NSAssert([frob length], @"Must have a well-formed frob response dictionary");
	NSString *URLString = [NSString stringWithFormat:@"%@?%@", authEndpoint, [self signedQueryFromArguments:[NSDictionary dictionaryWithObjectsAndKeys:frob, @"frob", inPermission, @"perms", nil]]];
	return [NSURL URLWithString:URLString];
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

- (void)setPhotoSource:(NSString *)inSource
{
	if (![inSource hasPrefix:@"http://"]) {
		return;
	}
	
	NSString *tmp = photoSource;
	photoSource = [inSource copy];
	[tmp release];
}

- (NSString *)photoSource
{
	return photoSource;
}

- (void)setAuthEndpoint:(NSString *)inEndpoint
{
	NSString *tmp = authEndpoint;
	authEndpoint = [inEndpoint copy];
	[tmp release];
}

- (NSString *)authEndpoint
{
	return authEndpoint;
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

- (OFFlickrAPIContext *)context
{
	return context;
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
    if ([HTTPRequest isRunning]) {
        return NO;
    }
    
    // combine the parameters 
	NSMutableDictionary *newArgs = [NSMutableDictionary dictionaryWithDictionary:inArguments];
	[newArgs setObject:inMethodName forKey:@"method"];	
	NSString *query = [context signedQueryFromArguments:newArgs];
	NSString *URLString = [NSString stringWithFormat:@"%@?%@", [context RESTAPIEndpoint], query];
	
    [HTTPRequest setContentType:nil];
	return [HTTPRequest performMethod:LFHTTPRequestGETMethod onURL:[NSURL URLWithString:URLString] withData:nil];
}

- (BOOL)callAPIMethodWithPOST:(NSString *)inMethodName arguments:(NSDictionary *)inArguments
{
    if ([HTTPRequest isRunning]) {
        return NO;
    }
    
    // combine the parameters 
	NSMutableDictionary *newArgs = [NSMutableDictionary dictionaryWithDictionary:inArguments];
	[newArgs setObject:inMethodName forKey:@"method"];	
	NSString *arguments = [context signedQueryFromArguments:newArgs];
    NSData *postData = [arguments dataUsingEncoding:NSUTF8StringEncoding];

	[HTTPRequest setContentType:LFHTTPRequestWWWFormURLEncodedContentType];
	return [HTTPRequest performMethod:LFHTTPRequestPOSTMethod onURL:[NSURL URLWithString:[context RESTAPIEndpoint]] withData:postData];
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
