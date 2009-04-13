//
// OFUtilities.h
//
// Copyright (c) 2007-2009 Lithoglyph Inc. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>

NS_INLINE NSString *OFMD5HexStringFromNSString(NSString *inStr)
{
    const char *data = [inStr UTF8String];
    size_t length = strlen(data);
    
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

NS_INLINE NSString *OFEscapedURLStringFromNSString(NSString *inStr)
{
	CFStringRef escaped = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)inStr, NULL, CFSTR("&"), kCFStringEncodingUTF8);
	
    #if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4	
	return (NSString *)[escaped autorelease];			    
    #else
	return (NSString *)[NSMakeCollectable(escaped) autorelease];			    
	#endif
}
