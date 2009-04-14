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

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
    #import <CoreFoundation/CoreFoundation.h>
    #import <CFNetwork/CFNetwork.h>
    #import <CFNetwork/CFProxySupport.h>
#endif

extern NSString *LFHTTPRequestConnectionError;
extern NSString *LFHTTPRequestTimeoutError;
extern NSTimeInterval LFHTTPRequestDefaultTimeoutInterval;
extern NSString *LFHTTPRequestWWWFormURLEncodedContentType;
extern NSString *LFHTTPRequestGETMethod;
extern NSString *LFHTTPRequestPOSTMethod;

@interface LFHTTPRequest : NSObject
{
    id _delegate;

    NSTimeInterval _timeoutInterval;
    NSString *_userAgent;
    NSString *_contentType;

    NSDictionary *_requestHeader;
    
    NSMutableData *_receivedData;
    NSString *_receivedContentType;
    
    CFReadStreamRef _readStream;
    NSTimer *_receivedDataTracker;
    NSTimeInterval _lastReceivedDataUpdateTime;
    
    NSTimer *_requestMessageBodyTracker;
    NSTimeInterval _lastSentDataUpdateTime;
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
    NSUInteger _requestMessageBodySize;
    NSUInteger _expectedDataLength;
    NSUInteger _lastReceivedBytes;
    NSUInteger _lastSentBytes;
#else
    unsigned int _requestMessageBodySize;
    unsigned int _expectedDataLength;
    unsigned int _lastReceivedBytes;
    unsigned int _lastSentBytes;
#endif

    void *_readBuffer;
    size_t _readBufferSize;
    
    id _sessionInfo;
}
// + (NSData *)fetchDataSynchronouslyFromURL:(NSURL *)url;
// + (NSData *)fetchDataSynchronouslyFromURL:(NSURL *)url byPostingData:(NSData *)data;
// + (NSData *)fetchDataSynchronouslyFromURL:(NSURL *)url byPostingMultipartData:(NSArray *)arrayOfData;
// + (NSData *)fetchDataSynchronouslyFromURL:(NSURL *)url byPostingDictionary:(NSDictionary *)dictionary;
- (id)init;
- (BOOL)isRunning;
- (void)cancel;
- (void)cancelWithoutDelegateMessage;
- (BOOL)performMethod:(NSString *)methodName onURL:(NSURL *)url withData:(NSData *)data;

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
- (BOOL)performMethod:(NSString *)methodName onURL:(NSURL *)url withInputStream:(NSInputStream *)inputStream knownContentSize:(NSUInteger)byteStreamSize;
#else
- (BOOL)performMethod:(NSString *)methodName onURL:(NSURL *)url withInputStream:(NSInputStream *)inputStream knownContentSize:(unsigned int)byteStreamSize;
#endif

- (NSData *)getReceivedDataAndDetachFromRequest;

- (NSDictionary *)requestHeader;
- (void)setRequestHeader:(NSDictionary *)requestHeader;
- (NSTimeInterval)timeoutInterval;
- (void)setTimeoutInterval:(NSTimeInterval)timeoutInterval;
- (NSString *)userAgent;
- (void)setUserAgent:(NSString *)userAgent;
- (NSString *)contentType;
- (void)setContentType:(NSString *)contentType;
- (NSData *)receivedData;
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
- (NSUInteger)expectedDataLength;
#else
- (unsigned int)expectedDataLength;
#endif
- (id)delegate;
- (void)setDelegate:(id)delegate;

- (void)setSessionInfo:(id)aSessionInfo;
- (id)sessionInfo;

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
@property(copy, readwrite) NSDictionary *requestHeader;
@property(assign, readwrite) NSTimeInterval timeoutInterval;
@property(copy, readwrite) NSString *userAgent;
@property(copy, readwrite) NSString *contentType;
@property(assign, readonly) NSData *receivedData;
@property(assign, readonly) NSUInteger expectedDataLength;
@property(assign, readwrite) id delegate;
@property(retain, readwrite) id sessionInfo;
#endif
@end

@interface NSObject (LFHTTPRequestDelegate)
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
- (void)httpRequest:(LFHTTPRequest *)request didReceiveStatusCode:(NSUInteger)statusCode URL:(NSURL *)url responseHeader:(CFHTTPMessageRef)header;
- (void)httpRequestDidComplete:(LFHTTPRequest *)request;
- (void)httpRequestDidCancel:(LFHTTPRequest *)request;
- (void)httpRequest:(LFHTTPRequest *)request didFailWithError:(NSString *)error;
- (void)httpRequest:(LFHTTPRequest *)request receivedBytes:(NSUInteger)bytesReceived expectedTotal:(NSUInteger)total;
- (void)httpRequest:(LFHTTPRequest *)request sentBytes:(NSUInteger)bytesSent total:(NSUInteger)total;

// note if you implemented this, the data is never written to the receivedData of the HTTP request instance
- (void)httpRequest:(LFHTTPRequest *)request writeReceivedBytes:(void *)bytes size:(NSUInteger)blockSize expectedTotal:(NSUInteger)total;
#else
- (void)httpRequest:(LFHTTPRequest *)request didReceiveStatusCode:(unsigned int)statusCode URL:(NSURL *)url responseHeader:(CFHTTPMessageRef)header;
- (void)httpRequestDidComplete:(LFHTTPRequest *)request;
- (void)httpRequestDidCancel:(LFHTTPRequest *)request;
- (void)httpRequest:(LFHTTPRequest *)request didFailWithError:(NSString *)error;
- (void)httpRequest:(LFHTTPRequest *)request receivedBytes:(unsigned int)bytesReceived expectedTotal:(unsigned int)total;
- (void)httpRequest:(LFHTTPRequest *)request sentBytes:(unsigned int)bytesSent total:(unsigned int)total;
- (void)httpRequest:(LFHTTPRequest *)request writeReceivedBytes:(void *)bytes size:(unsigned int)blockSize expectedTotal:(unsigned int)total;
#endif
@end