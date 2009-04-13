//
// OFXMLMapper.m
//
// Copyright (c) 2007-2009 Lithoglyph Inc. All rights reserved.
//

#import "OFXMLMapper.h"

NSString *OFXMLMapperExceptionName = @"OFXMLMapperException";
NSString *OFXMLTextContentKey = @"TextContent";

@implementation OFXMLMapper
- (void)dealloc
{
    [resultantDictionary release];
	[elementStack release];
    [super dealloc];
}

- (id)init
{
    if (self = [super init]) {
        resultantDictionary = [[NSMutableDictionary alloc] init];
		elementStack = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)runWithData:(NSData *)inData
{
	currentDictionary = resultantDictionary;
	
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:inData];
	[parser setDelegate:self];
	[parser parse];
	[parser release];
}

- (NSDictionary *)resultantDictionary
{
	return [[resultantDictionary retain] autorelease];
}

+ (NSDictionary *)dictionaryMappedFromXMLData:(NSData *)inData
{
	OFXMLMapper *mapper = [[OFXMLMapper alloc] init];
	[mapper runWithData:inData];
	NSDictionary *result = [mapper resultantDictionary];
	[mapper release];
	return result;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	NSMutableDictionary *mutableAttrDict = attributeDict ? [NSMutableDictionary dictionaryWithDictionary:attributeDict] : [NSMutableDictionary dictionary];

	// see if it's duplicated
	id element;
	if (element = [currentDictionary objectForKey:elementName]) {
		if (![element isKindOfClass:[NSMutableArray class]]) {
			if ([element isKindOfClass:[NSMutableDictionary class]]) {
				[element retain];
				[currentDictionary removeObjectForKey:elementName];
				
				NSMutableArray *newArray = [NSMutableArray arrayWithObject:element];
				[currentDictionary setObject:newArray forKey:elementName];
				[element release];
				
				element = newArray;
			}
			else {
				@throw [NSException exceptionWithName:OFXMLMapperExceptionName reason:@"Faulty XML structure" userInfo:nil];
			}
		}
		
		[element addObject:[NSMutableDictionary dictionaryWithDictionary:mutableAttrDict]];
	}
	else {
		[currentDictionary setObject:mutableAttrDict forKey:elementName];
	}
	
	[elementStack insertObject:currentDictionary atIndex:0];
	currentDictionary = mutableAttrDict;
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if (![elementStack count]) {
		@throw [NSException exceptionWithName:OFXMLMapperExceptionName reason:@"Unbalanced XML element tag closing" userInfo:nil];
	}
	
	currentDictionary = [elementStack objectAtIndex:0];
	[elementStack removeObjectAtIndex:0];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	[currentDictionary setObject:string forKey:OFXMLTextContentKey];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	[resultantDictionary release];
	resultantDictionary = nil;
}
@end
