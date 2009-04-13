//
// ObjectiveFlickr.h
//
// Copyright (c) 2007-2009 Lithoglyph Inc. All rights reserved.
//

#import "LFWebAPIKit.h"

@interface OFFlickrAPIContext : NSObject
{
    NSString *key;
    NSString *sharedSecret;
    NSString *authToken;
    
    NSString *RESTAPIEndpoint;
}
- (id)initWithAPIKey:(NSString *)inKey sharedSecret:(NSString *)inSharedSecret;

- (void)setAuthToken:(NSString *)inAuthToken;
- (NSString *)authToken;

- (void)setRESTAPIEndpoint:(NSString *)inEndpoint;
- (NSString *)RESTAPIEndpoint;

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readonly) NSString *sharedSecret;
@property (nonatomic, retain) NSString *authToken;

@property (nonatomic, retain) NSString *RESTAPIEndpoint;
#endif
@end

enum {
    OFFlickrAPIRequestConnectionError = 1,
    OFFlickrAPIRequestTimeoutError = 2,
    
    OFFlickrAPIRequestUnknownError = 42
};

@class OFFlickrAPIRequest;

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
@protocol OFFlickrAPIRequestDelegate <NSObject>
#else
@interface NSObject (OFFlickrAPIRequestDelegateCategory)
#endif
- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary;
- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)error;
@end

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
typedef id<OFFlickrAPIRequestDelegate> OFFlickrAPIRequestDelegateType;
#else
typedef id OFFlickrAPIRequestDelegateType;
#endif

@interface OFFlickrAPIRequest : NSObject
{
    OFFlickrAPIContext *context;
    LFHTTPRequest *HTTPRequest;
    
    OFFlickrAPIRequestDelegateType delegate;
}
- (id)initWithAPIContext:(OFFlickrAPIContext *)inContext;
- (OFFlickrAPIRequestDelegateType)delegate;
- (void)setDelegate:(OFFlickrAPIRequestDelegateType)inDelegate;
- (NSTimeInterval)requestTimeoutInterval;
- (void)setRequestTimeoutInterval:(NSTimeInterval)inTimeInterval;
- (BOOL)isRunning;
- (void)cancel;

// elementary methods
- (BOOL)callAPIMethodWithGET:(NSString *)inMethodName arguments:(NSDictionary *)inArguments;

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
@property (nonatomic, assign) OFFlickrAPIRequestDelegateType delegate;
@property (nonatomic, assign) NSTimeInterval requestTimeoutInterval;
#endif
@end
