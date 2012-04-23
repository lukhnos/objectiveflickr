//
// OFUtilities.m
//
// Copyright (c) 2009-2011 Lukhnos D. Liu (http://lukhnos.org)
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

#import "OFUtilities.h"
#import <CommonCrypto/CommonDigest.h>

NSString *OFMD5HexStringFromNSString(NSString *inStr)
{
    const char *data = [inStr UTF8String];
    CC_LONG length = (CC_LONG) strlen(data);
    
    unsigned char *md5buf = (unsigned char*)calloc(1, CC_MD5_DIGEST_LENGTH);
    
    CC_MD5_CTX md5ctx;
    CC_MD5_Init(&md5ctx);
    CC_MD5_Update(&md5ctx, data, length);
    CC_MD5_Final(md5buf, &md5ctx);
    
    NSMutableString *md5hex = [NSMutableString string];
	size_t i;
    for (i = 0 ; i < CC_MD5_DIGEST_LENGTH ; i++) {
        [md5hex appendFormat:@"%02x", md5buf[i]];
    }
    free(md5buf);
    return md5hex;
}

NSString *OFEscapedURLStringFromNSString(NSString *inStr)
{
	return OFEscapedURLStringFromNSStringWithExtraEscapedChars(inStr, @"&");
}

NSString *OFEscapedURLStringFromNSStringWithExtraEscapedChars(NSString *inStr, NSString *inEscChars)
{
	CFStringRef escaped = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)inStr, NULL, (CFStringRef)inEscChars, kCFStringEncodingUTF8);
    
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4	
	return (NSString *)[(NSString*)escaped autorelease];			    
#else
	return (NSString *)[NSMakeCollectable(escaped) autorelease];			    
#endif    
}

NSString *OFGenerateUUIDString(void)
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4	
	return (NSString *)[(NSString*)uuidStr autorelease];			    
#else
	return (NSString *)[NSMakeCollectable(uuidStr) autorelease];			    
#endif	
}

static NSData *OFSha1(NSData *inData)
{
    NSMutableData *result = [NSMutableData dataWithLength:CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_CTX context;
    CC_SHA1_Init(&context);
    CC_SHA1_Update(&context, [inData bytes], (CC_LONG)[inData length]);
    CC_SHA1_Final([result mutableBytes], &context);
    return result;
}

static char *NewBase64Encode(const void *buffer, size_t length, bool separateLines, size_t *outputLength);


// http://en.wikipedia.org/wiki/HMAC
NSString *OFHMACSha1Base64(NSString *inKey, NSString *inMessage)
{
    NSData *keyData = [inKey dataUsingEncoding:NSUTF8StringEncoding];
    
    if ([keyData length] > CC_SHA1_BLOCK_BYTES) {
        keyData = OFSha1(keyData);
    }
    
    if ([keyData length] < CC_SHA1_BLOCK_BYTES) {
        NSUInteger padSize = CC_SHA1_BLOCK_BYTES - [keyData length];

        NSMutableData *paddedData = [NSMutableData dataWithData:keyData];
        [paddedData appendData:[NSMutableData dataWithLength:padSize]];
        keyData  = paddedData;
    }
    
    NSMutableData *oKeyPad = [NSMutableData dataWithLength:CC_SHA1_BLOCK_BYTES];
    NSMutableData *iKeyPad = [NSMutableData dataWithLength:CC_SHA1_BLOCK_BYTES];

    const uint8_t *kdPtr = [keyData bytes];
    uint8_t *okpPtr = [oKeyPad mutableBytes];
    uint8_t *ikpPtr = [iKeyPad mutableBytes];

    memset(okpPtr, 0x5c, CC_SHA1_BLOCK_BYTES);
    memset(ikpPtr, 0x36, CC_SHA1_BLOCK_BYTES);
    
    NSUInteger i;
    for (i = 0; i < CC_SHA1_BLOCK_BYTES; i++) {
        okpPtr[i] = okpPtr[i] ^ kdPtr[i];
        ikpPtr[i] = ikpPtr[i] ^ kdPtr[i];
    }
    
    NSData *msgData = [inMessage dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableData *innerData = [NSMutableData dataWithData:iKeyPad];
    [innerData appendData:msgData];
    NSData *innerDataHashed = OFSha1(innerData);
    
    NSMutableData *outerData = [NSMutableData dataWithData:oKeyPad];
    [outerData appendData:innerDataHashed];
    
    NSData *outerHashedData = OFSha1(outerData);
    
    
	size_t outputLength;
	char *outputBuffer = NewBase64Encode([outerHashedData bytes], [outerHashedData length], true, &outputLength);
	
	NSString *result = [[[NSString alloc] initWithBytes:outputBuffer length:outputLength encoding:NSASCIIStringEncoding] autorelease];
	free(outputBuffer);
	return result;    
}

NSDictionary *OFExtractURLQueryParameter(NSString *inQuery)
{
    if (![inQuery length]) {
        return nil;        
    }

    NSArray *params = [inQuery componentsSeparatedByString:@"&"];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSString *p in params) {
        NSArray *kv = [p componentsSeparatedByString:@"="];
        if ([kv count] != 2) {
            return nil;
        }
        
        [dict setObject:[kv objectAtIndex:1] forKey:[kv objectAtIndex:0]];
    }
    return dict;
}

BOOL OFExtractOAuthCallback(NSURL *inReceivedURL, NSURL *inBaseURL, NSString **outRequestToken, NSString **outVerifier)
{
    assert(outRequestToken && "outRequestToken cannot be nil");
    assert(outVerifier && "outVerifier cannot be nil");
    
    NSString *ruStr = [inReceivedURL absoluteString];
    NSString *buStr = [[inBaseURL absoluteString] stringByAppendingString:@"?"];
    
    if (![ruStr hasPrefix:buStr]) {
        return NO;
    }
    
    NSString *query = [ruStr substringFromIndex:[buStr length]];
    if (![query length]) {
        return NO;
    }
    
    NSDictionary *dict = OFExtractURLQueryParameter(query);
    if (!dict) {
        return NO;
    }
    
    NSString *t = [dict objectForKey:@"oauth_token"];
    NSString *v = [dict objectForKey:@"oauth_verifier"];
    
    if (!t || !v) {
        return NO;
    }
    
    *outRequestToken = [[t copy] autorelease];
    *outVerifier = [[v copy] autorelease];
    return YES;
}



// From http://cocoawithlove.com/2009/06/base64-encoding-options-on-mac-and.html
//
// License header:
//
//  Created by Matt Gallagher on 2009/06/03.
//  Copyright 2009 Matt Gallagher. All rights reserved.
//
//  This software is provided 'as-is', without any express or implied
//  warranty. In no event will the authors be held liable for any damages
//  arising from the use of this software. Permission is granted to anyone to
//  use this software for any purpose, including commercial applications, and to
//  alter it and redistribute it freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source
//     distribution.
//



//
// Mapping from 6 bit pattern to ASCII character.
//
static unsigned char base64EncodeLookup[65] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";


//
// Fundamental sizes of the binary and base64 encode/decode units in bytes
//
#define BINARY_UNIT_SIZE 3
#define BASE64_UNIT_SIZE 4

//
// NewBase64Encode
//
// Encodes the arbitrary data in the inputBuffer as base64 into a newly malloced
// output buffer.
//
//  inputBuffer - the source data for the encode
//	length - the length of the input in bytes
//  separateLines - if zero, no CR/LF characters will be added. Otherwise
//		a CR/LF pair will be added every 64 encoded chars.
//	outputLength - if not-NULL, on output will contain the encoded length
//		(not including terminating 0 char)
//
// returns the encoded buffer. Must be free'd by caller. Length is given by
//	outputLength.
//
static char *NewBase64Encode(
                      const void *buffer,
                      size_t length,
                      bool separateLines,
                      size_t *outputLength)
{
	const unsigned char *inputBuffer = (const unsigned char *)buffer;
	
#define MAX_NUM_PADDING_CHARS 2
#define OUTPUT_LINE_LENGTH 64
#define INPUT_LINE_LENGTH ((OUTPUT_LINE_LENGTH / BASE64_UNIT_SIZE) * BINARY_UNIT_SIZE)
#define CR_LF_SIZE 2
	
	//
	// Byte accurate calculation of final buffer size
	//
	size_t outputBufferSize =
    ((length / BINARY_UNIT_SIZE)
     + ((length % BINARY_UNIT_SIZE) ? 1 : 0))
    * BASE64_UNIT_SIZE;
	if (separateLines)
	{
		outputBufferSize +=
        (outputBufferSize / OUTPUT_LINE_LENGTH) * CR_LF_SIZE;
	}
	
	//
	// Include space for a terminating zero
	//
	outputBufferSize += 1;
    
	//
	// Allocate the output buffer
	//
	char *outputBuffer = (char *)malloc(outputBufferSize);
	if (!outputBuffer)
	{
		return NULL;
	}
    
	size_t i = 0;
	size_t j = 0;
	const size_t lineLength = separateLines ? INPUT_LINE_LENGTH : length;
	size_t lineEnd = lineLength;
	
	while (true)
	{
		if (lineEnd > length)
		{
			lineEnd = length;
		}
        
		for (; i + BINARY_UNIT_SIZE - 1 < lineEnd; i += BINARY_UNIT_SIZE)
		{
			//
			// Inner loop: turn 48 bytes into 64 base64 characters
			//
			outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i] & 0xFC) >> 2];
			outputBuffer[j++] = base64EncodeLookup[((inputBuffer[i] & 0x03) << 4)
                                                   | ((inputBuffer[i + 1] & 0xF0) >> 4)];
			outputBuffer[j++] = base64EncodeLookup[((inputBuffer[i + 1] & 0x0F) << 2)
                                                   | ((inputBuffer[i + 2] & 0xC0) >> 6)];
			outputBuffer[j++] = base64EncodeLookup[inputBuffer[i + 2] & 0x3F];
		}
		
		if (lineEnd == length)
		{
			break;
		}
		
		//
		// Add the newline
		//
		outputBuffer[j++] = '\r';
		outputBuffer[j++] = '\n';
		lineEnd += lineLength;
	}
	
	if (i + 1 < length)
	{
		//
		// Handle the single '=' case
		//
		outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i] & 0xFC) >> 2];
		outputBuffer[j++] = base64EncodeLookup[((inputBuffer[i] & 0x03) << 4)
                                               | ((inputBuffer[i + 1] & 0xF0) >> 4)];
		outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i + 1] & 0x0F) << 2];
		outputBuffer[j++] =	'=';
	}
	else if (i < length)
	{
		//
		// Handle the double '=' case
		//
		outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i] & 0xFC) >> 2];
		outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i] & 0x03) << 4];
		outputBuffer[j++] = '=';
		outputBuffer[j++] = '=';
	}
	outputBuffer[j] = 0;
	
	//
	// Set the output length and return the buffer
	//
	if (outputLength)
	{
		*outputLength = j;
	}
	return outputBuffer;
}

