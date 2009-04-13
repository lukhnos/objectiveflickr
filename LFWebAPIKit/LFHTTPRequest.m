// LFHTTPRequest
//
// Copyright (c) 2006-2008 Lukhnos D. Liu (lukhnos at lithoglyph dot com)
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. Neither the name of this software nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#import <SystemConfiguration/SystemConfiguration.h>
#import "LFHTTPRequest.h"

// these typedefs are for this compilation unit only
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
	typedef unsigned int NSUInteger;
	typedef int NSInteger;
	#define NSUIntegerMax UINT_MAX
#endif



NSString *LFHRDefaultUserAgent = nil;

NSString *LFHTTPRequestConnectionError = @"HTTP request connection lost";
NSString *LFHTTPRequestTimeoutError = @"HTTP request timeout";
NSTimeInterval LFHTTPRequestDefaultTimeoutInterval = 10.0;
NSTimeInterval LFHTTPRequestDefaultTrackerFireInterval = 1.0;
NSString *LFHTTPRequestWWWFormURLEncodedContentType = @"application/x-www-form-urlencoded";
NSString *LFHTTPRequestGETMethod = @"GET";
NSString *LFHTTPRequestPOSTMethod = @"POST";


void LFHRReadStreamClientCallBack(CFReadStreamRef stream, CFStreamEventType eventType, void *clientCallBackInfo);

@interface LFHTTPRequest (PrivateMethods)
- (void)cleanUp;
- (void)dealloc;
- (void)handleTimeout;
- (void)handleRequestMessageBodyTrackerTick:(NSTimer *)timer;
- (void)handleReceivedDataTrackerTick:(NSTimer *)timer;
- (void)readStreamHasBytesAvailable;
- (void)readStreamErrorOccurred;
- (void)readStreamEndEncountered;
@end

@implementation LFHTTPRequest (PrivateMethods)
- (void)cleanUp
{
	if (_readStream) {
	    CFReadStreamUnscheduleFromRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes); 
	    CFReadStreamClose(_readStream); 
	    CFRelease(_readStream); 
	    _readStream = NULL;
	}
	
	if (_receivedDataTracker) {
        [_receivedDataTracker invalidate];
        [_receivedDataTracker release];
        _receivedDataTracker = nil;
	}
	
	if (_requestMessageBodyTracker) {
        [_requestMessageBodyTracker invalidate];
        [_requestMessageBodyTracker release];
        _requestMessageBodyTracker = nil;
	}

    _requestMessageBodySize = 0;	
    _expectedDataLength = NSUIntegerMax;    

    _lastReceivedDataUpdateTime = 0.0;
    _lastReceivedBytes = 0;
    
    _lastSentDataUpdateTime = 0.0;
    _lastSentBytes = 0;
    
}
- (void)dealloc
{
    [self cleanUp];
    [_userAgent release];
    [_contentType release];
    [_requestHeader release];
    [_receivedData release];
    [_receivedContentType release];
    
	if (_sessionInfo) {
		[_sessionInfo release];
		_sessionInfo = nil;
	}
    
	free(_readBuffer);
    [super dealloc];
}
- (void)handleTimeout
{
    [self cleanUp];
	if ([_delegate respondsToSelector:@selector(httpRequest:didFailWithError:)]) {
        [_delegate httpRequest:self didFailWithError:LFHTTPRequestTimeoutError];
	}    
}
- (void)handleRequestMessageBodyTrackerTick:(NSTimer *)timer
{
    if (timer != _requestMessageBodyTracker) {
        return;
    }
    
    // get the number of sent bytes
    CFTypeRef sentBytesObject = CFReadStreamCopyProperty(_readStream, kCFStreamPropertyHTTPRequestBytesWrittenCount);
    if (!sentBytesObject) {
        // or should we send an error message?
        return;
    }
    
    NSInteger signedSentBytes = 0;
    CFNumberGetValue(sentBytesObject, kCFNumberCFIndexType, &signedSentBytes);
    CFRelease(sentBytesObject);
    
    if (signedSentBytes < 0) {
        // or should we send an error message?
        return;
    }
    
    // interestingly, this logic also works when ALL REQUEST MESSAGE BODY IS SENT
    NSUInteger sentBytes = (NSUInteger)signedSentBytes;
    if (sentBytes > _lastSentBytes) {
        _lastSentBytes = sentBytes;
        _lastSentDataUpdateTime = [NSDate timeIntervalSinceReferenceDate];

        if ([_delegate respondsToSelector:@selector(httpRequest:sentBytes:total:)]) {
            [_delegate httpRequest:self sentBytes:_lastSentBytes total:_requestMessageBodySize];
        }

        return;
    }
    
    if ([NSDate timeIntervalSinceReferenceDate] - _lastSentDataUpdateTime > _timeoutInterval) {
        // remove ourselve from the runloop
        [_requestMessageBodyTracker invalidate];
        [self handleTimeout];        
    }
}
- (void)handleReceivedDataTrackerTick:(NSTimer *)timer
{
    if (timer != _receivedDataTracker) {
        return;
    }
    
    if ([NSDate timeIntervalSinceReferenceDate] - _lastReceivedDataUpdateTime > _timeoutInterval) {
        // remove ourselves from the runloop
        [_receivedDataTracker invalidate];
        [self handleTimeout];
    }
}
- (void)readStreamHasBytesAvailable
{
	// to prevent from stray callbacks entering here
	if (![self isRunning]) {
		return;
	}
	
	if (!_receivedDataTracker) {	    
	    // update one last time the total sent bytes
        if ([_delegate respondsToSelector:@selector(httpRequest:sentBytes:total:)]) {
            [_delegate httpRequest:self sentBytes:_requestMessageBodySize total:_requestMessageBodySize];
        }
	    
	    // stops _requestMessageBodyTracker
        [_requestMessageBodyTracker invalidate];
        [_requestMessageBodyTracker release];
        _requestMessageBodyTracker = nil;
        
        NSUInteger statusCode = 0;
	    
		CFURLRef finalURL = CFReadStreamCopyProperty(_readStream, kCFStreamPropertyHTTPFinalURL);
		CFHTTPMessageRef response = (CFHTTPMessageRef)CFReadStreamCopyProperty(_readStream, kCFStreamPropertyHTTPResponseHeader);
		if (response) {
			statusCode = (NSUInteger)CFHTTPMessageGetResponseStatusCode(response);
			
			CFStringRef contentLengthString = CFHTTPMessageCopyHeaderFieldValue(response, CFSTR("Content-Length"));
			if (contentLengthString) {
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
                _expectedDataLength = [(NSString *)contentLengthString integerValue];
#else
                _expectedDataLength = [(NSString *)contentLengthString intValue];
#endif
				CFRelease(contentLengthString);
			}

            [_receivedContentType release];
            _receivedContentType = nil;
			
            CFStringRef contentTypeString = CFHTTPMessageCopyHeaderFieldValue(response, CFSTR("Content-Type"));
            if (contentTypeString) {
                _receivedContentType = [(NSString *)contentTypeString copy];
                CFRelease(contentTypeString);
            }
		}
		
        CFReadStreamRef presentReadStream = _readStream;		
		
		if ([_delegate respondsToSelector:@selector(httpRequest:didReceiveStatusCode:URL:responseHeader:)]) {
            [_delegate httpRequest:self didReceiveStatusCode:statusCode URL:(NSURL *)finalURL responseHeader:response];
		}
		
		if (finalURL) {
			CFRelease(finalURL);		    
		}
		
		if (response) {
            CFRelease(response);
		}
		
		// better to see if we're still running... (we might be canceled by the delegate's httpRequest:didReceiveStatusCode:URL:responseHeader: !)
		if (presentReadStream != _readStream) {
			return;
		}
		
		// now we fire _receivedDataTracker
        _receivedDataTracker = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:LFHTTPRequestDefaultTrackerFireInterval target:self selector:@selector(handleReceivedDataTrackerTick:) userInfo:nil repeats:YES];
		#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
				// this is 10.5 only
				[[NSRunLoop currentRunLoop] addTimer:_receivedDataTracker forMode:NSRunLoopCommonModes];
		#endif
				
				[[NSRunLoop currentRunLoop] addTimer:_receivedDataTracker forMode:NSDefaultRunLoopMode];
				
				// These two are defined in the AppKit, not in the Foundation	
		#if TARGET_OS_MAC && !TARGET_OS_IPHONE
				extern NSString *NSModalPanelRunLoopMode;
				extern NSString *NSEventTrackingRunLoopMode;
				[[NSRunLoop currentRunLoop] addTimer:_receivedDataTracker forMode:NSEventTrackingRunLoopMode];
				[[NSRunLoop currentRunLoop] addTimer:_receivedDataTracker forMode:NSModalPanelRunLoopMode];
		#endif
		
        _lastReceivedBytes = 0;
        _lastReceivedDataUpdateTime = [NSDate timeIntervalSinceReferenceDate];
	}	
	
	// sets a 25,600-byte block, approximately for 256 KBPS connection
	CFIndex bytesRead = CFReadStreamRead(_readStream, _readBuffer, _readBufferSize); 
	if (bytesRead > 0) { 
		if ([_delegate respondsToSelector:@selector(httpRequest:writeReceivedBytes:size:expectedTotal:)]) {
			[_delegate httpRequest:self writeReceivedBytes:_readBuffer size:bytesRead expectedTotal:_expectedDataLength];

			_lastReceivedBytes += bytesRead;
			_lastReceivedDataUpdateTime = [NSDate timeIntervalSinceReferenceDate];
		
		}
		else {
			[_receivedData appendBytes:_readBuffer length:bytesRead];
			_lastReceivedBytes = [_receivedData length];
			_lastReceivedDataUpdateTime = [NSDate timeIntervalSinceReferenceDate];
			
			if ([_delegate respondsToSelector:@selector(httpRequest:receivedBytes:expectedTotal:)]) {
				[_delegate httpRequest:self receivedBytes:_lastReceivedBytes expectedTotal:_expectedDataLength];
			}                
		}
	} 
}
- (void)readStreamEndEncountered
{
	// to prevent from stray callbacks entering here
	if (![self isRunning]) {
		return;
	}
	
	[self cleanUp];

    if ([_delegate respondsToSelector:@selector(httpRequestDidComplete:)]) {
        [_delegate httpRequestDidComplete:self];
    }	
}
- (void)readStreamErrorOccurred
{
	// to prevent from stray callbacks entering here
	if (![self isRunning]) {
		return;
	}
		
	[self cleanUp];
	
	if ([_delegate respondsToSelector:@selector(httpRequest:didFailWithError:)]) {
        [_delegate httpRequest:self didFailWithError:LFHTTPRequestConnectionError];
	}
}
@end

@implementation LFHTTPRequest
- (id)init
{
    if (self = [super init]) {
        _delegate = nil;
        _timeoutInterval = LFHTTPRequestDefaultTimeoutInterval;
        _userAgent = nil;
        _contentType = nil;
        _requestHeader = nil;
        _requestMessageBodySize = 0;

        _receivedData = [NSMutableData new];
        _expectedDataLength = NSUIntegerMax;
        _receivedContentType = nil;
        _readStream = NULL;
        _receivedDataTracker = nil;
        _lastReceivedDataUpdateTime = 0.0;
        _lastReceivedBytes = 0;
        
        _requestMessageBodyTracker = nil;
        _lastSentDataUpdateTime = 0.0;
        _lastSentBytes = 0;
		
		_readBufferSize = 25600;
		_readBuffer = calloc(1, _readBufferSize);
		assert(_readBuffer);
    }
    
    return self;
}
- (BOOL)isRunning
{
    return !!_readStream;
}
- (BOOL)performMethod:(NSString *)methodName onURL:(NSURL *)url withData:(NSData *)data
{
	if (_readStream) {
		return NO;
	}
	
	CFHTTPMessageRef request = CFHTTPMessageCreateRequest(NULL, (CFStringRef)methodName, (CFURLRef)url, kCFHTTPVersion1_1);
	if (!request) {
		return NO;
	}

	// combine the header
    NSMutableDictionary *headerDictionary = [NSMutableDictionary dictionary];
    if (_userAgent) {
        [headerDictionary setObject:_userAgent forKey:@"User-Agent"];
    }
	
	if (_contentType) {
        [headerDictionary setObject:_contentType forKey:@"Content-Type"];
	}
	
	if ([data length]) {
		[headerDictionary setObject:[NSString stringWithFormat:@"%lu", [data length]] forKey:@"Content-Length"];
	}
    
    if (_requestHeader) {
        [headerDictionary addEntriesFromDictionary:_requestHeader];
    }
    
	NSEnumerator *dictEnumerator = [headerDictionary keyEnumerator];
	id key;
	while (key = [dictEnumerator nextObject]) {
        CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)[key description], (CFStringRef)[headerDictionary objectForKey:key]);
	}
	
	CFHTTPMessageSetBody(request, (CFDataRef)data);	

	NSDictionary *headerCheck = (NSDictionary*)CFHTTPMessageCopyAllHeaderFields(request);
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
	NSMakeCollectable((CFTypeRef)headerCheck);
#endif
	[headerCheck release];

	CFReadStreamRef tmpReadStream = CFReadStreamCreateForHTTPRequest(NULL, request);
	CFRelease(request);	
	if (!tmpReadStream) {
		return NO;
	}

	CFReadStreamSetProperty(tmpReadStream, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue);
	
	// apply current proxy settings
	#if !TARGET_OS_IPHONE
		CFDictionaryRef proxyDict = SCDynamicStoreCopyProxies(NULL); // kCFNetworkProxiesHTTPProxy
	#else
		#if TARGET_IPHONE_SIMULATOR
			CFDictionaryRef proxyDict = (CFDictionaryRef)[[NSDictionary alloc] init];
		#else
			CFDictionaryRef proxyDict = CFNetworkCopySystemProxySettings();
		#endif
	#endif

	if (proxyDict) {
		CFReadStreamSetProperty(tmpReadStream, kCFStreamPropertyHTTPProxy, proxyDict);	
		CFRelease(proxyDict);
	}
	
	CFStreamClientContext streamContext;
	streamContext.version = 0;
	streamContext.info = self;
	streamContext.retain = 0;
	streamContext.release = 0;
	streamContext.copyDescription = 0;

	CFOptionFlags eventFlags = kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred;
	
	// open the stream with callback function
	if (!CFReadStreamSetClient(tmpReadStream, eventFlags, LFHRReadStreamClientCallBack, &streamContext))
	{
		CFRelease(tmpReadStream);
		return NO;
	}
	
    // detach and release the previous data buffer
    if ([_receivedData length]) {
        NSMutableData *tmp = _receivedData;
        _receivedData = [NSMutableData new];
        [tmp release];
    }	

	CFReadStreamScheduleWithRunLoop(tmpReadStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);

    // we need to assign this in advance, because the callback might be called anytime between this and the next statement
	_readStream = tmpReadStream;
    
    _expectedDataLength = NSUIntegerMax;
    _requestMessageBodySize = [data length];

    // open the stream
	Boolean result = CFReadStreamOpen(tmpReadStream);	
	if (!result) {
		CFReadStreamUnscheduleFromRunLoop(tmpReadStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
		CFRelease(tmpReadStream);
		_readStream = NULL;
		return NO;
	}

	
	// we create _requestMessageBodyTracker (timer for tracking sent data) first
    _requestMessageBodyTracker = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:LFHTTPRequestDefaultTrackerFireInterval target:self selector:@selector(handleRequestMessageBodyTrackerTick:) userInfo:nil repeats:YES];

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
	// this is 10.5 only
	[[NSRunLoop currentRunLoop] addTimer:_requestMessageBodyTracker forMode:NSRunLoopCommonModes];
#endif

	[[NSRunLoop currentRunLoop] addTimer:_requestMessageBodyTracker forMode:NSDefaultRunLoopMode];

	// These two are defined in the AppKit, not in the Foundation	
	#if TARGET_OS_MAC && !TARGET_OS_IPHONE
	extern NSString *NSModalPanelRunLoopMode;
	extern NSString *NSEventTrackingRunLoopMode;
	[[NSRunLoop currentRunLoop] addTimer:_requestMessageBodyTracker forMode:NSEventTrackingRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:_requestMessageBodyTracker forMode:NSModalPanelRunLoopMode];
	#endif
	
    _lastSentBytes = 0;
    _lastSentDataUpdateTime = [NSDate timeIntervalSinceReferenceDate];

	return YES;
}
- (void)cancel
{
    [self cancelWithoutDelegateMessage];
    if ([_delegate respondsToSelector:@selector(httpRequestDidCancel:)]) {
        [_delegate httpRequestDidCancel:self];
    }
}
- (void)cancelWithoutDelegateMessage
{
    [self cleanUp];
}
- (NSData *)getReceivedDataAndDetachFromRequest
{
    NSData *returnedData = [_receivedData autorelease];
    _receivedData = [NSMutableData new];
    
    [_receivedContentType release];
    _receivedContentType = nil;
    
	return returnedData;
}
- (NSDictionary *)requestHeader
{
	return [[_requestHeader copy] autorelease];
}
- (void)setRequestHeader:(NSDictionary *)requestHeader
{
	if (![_requestHeader isEqualToDictionary:requestHeader]) {
		NSDictionary *tmp = _requestHeader;
		_requestHeader = [requestHeader copy];
		[tmp release];
	}
}
- (NSTimeInterval)timeoutInterval
{
	return _timeoutInterval;
}
- (void)setTimeoutInterval:(NSTimeInterval)timeoutInterval
{
	if (_timeoutInterval != timeoutInterval) {
		_timeoutInterval = timeoutInterval;
	}
}
- (NSString *)userAgent
{
	return [[_userAgent copy] autorelease];
}
- (void)setUserAgent:(NSString *)userAgent
{
	if ([_userAgent isEqualToString:userAgent]) {
		return;
	}
	
	NSString *tmp = _userAgent;
	_userAgent = [userAgent copy];
	[tmp release];
}
- (NSString *)contentType
{
	return [[_contentType copy] autorelease];
}
- (void)setContentType:(NSString *)contentType
{
	if ([_contentType isEqualToString:contentType]) {
		return;
	}
	
	NSString *tmp = _contentType;
	_contentType = [contentType copy];
	[tmp release];
}
- (NSData *)receivedData
{
	return [[_receivedData retain] autorelease];
}
- (NSUInteger)expectedDataLength
{
	return _expectedDataLength;
}
- (id)delegate
{
	return _delegate;
}
- (void)setDelegate:(id)delegate
{
	if (delegate != _delegate) {
		_delegate = delegate;
	}
}

- (void)setSessionInfo:(id)aSessionInfo
{
	id tmp = _sessionInfo;
	_sessionInfo = [aSessionInfo retain];
	[tmp release];
}
- (id)sessionInfo
{
	return [[_sessionInfo retain] autorelease];
}

@end

void LFHRReadStreamClientCallBack(CFReadStreamRef stream, CFStreamEventType eventType, void *clientCallBackInfo)
{
	id pool = [NSAutoreleasePool new];
	LFHTTPRequest *request = (LFHTTPRequest *)clientCallBackInfo;
	switch (eventType) {
		case kCFStreamEventHasBytesAvailable:
			[request readStreamHasBytesAvailable];
			break;
		case kCFStreamEventEndEncountered:
			[request readStreamEndEncountered];
			break;
		case kCFStreamEventErrorOccurred:
			[request readStreamErrorOccurred];
			break;
	}
	[pool drain];
}
