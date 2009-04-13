//
// ObjectiveFlickr.h
//
// Copyright (c) 2007-2009 Lithoglyph Inc. All rights reserved.
//

#import "LFWebAPIKit.h"

extern NSString *OFFlickrSmallSquareSize;		// "s" - 75x75
extern NSString *OFFlickrThumbnailSize;			// "t" - 100 on longest side
extern NSString *OFFlickrSmallSize;				// "m" - 240 on longest side
extern NSString *OFFlickrMediumSize;			// (no size modifier) - 500 on longest side
extern NSString *OFFlickrLargeSize;				// "b" - 1024 on longest side

extern NSString *OFFlickrReadPermission;
extern NSString *OFFlickrWritePermission;
extern NSString *OFFlickrDeletePermission;

@interface OFFlickrAPIContext : NSObject
{
    NSString *key;
    NSString *sharedSecret;
    NSString *authToken;
    
    NSString *RESTAPIEndpoint;
	NSString *photoSource;
	NSString *authEndpoint;
}
- (id)initWithAPIKey:(NSString *)inKey sharedSecret:(NSString *)inSharedSecret;

- (void)setAuthToken:(NSString *)inAuthToken;
- (NSString *)authToken;

// URL provisioning
- (NSURL *)photoSourceURLFromDictionary:(NSDictionary *)inDictionary size:(NSString *)inSizeModifier;
- (NSURL *)loginURLFromFrobDictionary:(NSDictionary *)inFrob requestedPermission:(NSString *)inPermission;

// API endpoints
- (void)setRESTAPIEndpoint:(NSString *)inEndpoint;
- (NSString *)RESTAPIEndpoint;

- (void)setPhotoSource:(NSString *)inSource;
- (NSString *)photoSource;

- (void)setAuthEndpoint:(NSString *)inEndpoint;
- (NSString *)authEndpoint;

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readonly) NSString *sharedSecret;
@property (nonatomic, retain) NSString *authToken;

@property (nonatomic, retain) NSString *RESTAPIEndpoint;
@property (nonatomic, retain) NSString *photoSource;
#endif
@end

extern NSString *OFFlickrAPIReturnedErrorDomain;
extern NSString *OFFlickrAPIRequestErrorDomain;

enum {
	// refer to Flickr API document for Flickr's own error codes
    OFFlickrAPIRequestConnectionError = 0x7fff0001,
    OFFlickrAPIRequestTimeoutError = 0x7fff0002,    
	OFFlickrAPIRequestFaultyXMLResponseError = 0x7fff0003,
    OFFlickrAPIRequestUnknownError = 0x7fff0042
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
- (OFFlickrAPIContext *)context;
- (OFFlickrAPIRequestDelegateType)delegate;
- (void)setDelegate:(OFFlickrAPIRequestDelegateType)inDelegate;
- (NSTimeInterval)requestTimeoutInterval;
- (void)setRequestTimeoutInterval:(NSTimeInterval)inTimeInterval;
- (BOOL)isRunning;
- (void)cancel;

// elementary methods
- (BOOL)callAPIMethodWithGET:(NSString *)inMethodName arguments:(NSDictionary *)inArguments;

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
@property (nonatomic, readonly) OFFlickrAPIContext *context;
@property (nonatomic, assign) OFFlickrAPIRequestDelegateType delegate;
@property (nonatomic, assign) NSTimeInterval requestTimeoutInterval;
#endif
@end
