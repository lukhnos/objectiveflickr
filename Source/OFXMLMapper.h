//
// OFXMLMapper.h
//
// Copyright (c) 2007-2009 Lithoglyph Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *OFXMLTextContentKey;

@interface OFXMLMapper : NSObject
{
    NSMutableDictionary *resultantDictionary;
	
	NSMutableArray *elementStack;
	NSMutableDictionary *currentDictionary;
	NSString *currentElementName;
}
+ (NSDictionary *)dictionaryMappedFromXMLData:(NSData *)inData;
@end
