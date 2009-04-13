// [AUTO_HEADER]

#import "NSData+LFHTTPFormExtensions.h"

@implementation NSData (LFHTTPFormExtensions)
+ (id)dataAsWWWURLEncodedFormFromDictionary:(NSDictionary *)formDictionary
{
    NSMutableString *combinedDataString = [NSMutableString string];
    NSEnumerator *enumerator = [formDictionary keyEnumerator];
    id key;
    id value;

    if (key = [enumerator nextObject]) {
        value = [formDictionary objectForKey:key];
        [combinedDataString appendString:[NSString stringWithFormat:@"%@=%@", [(NSString*)key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];

		while ((key = [enumerator nextObject])) {
			value = [formDictionary objectForKey:key];        
			[combinedDataString appendString:[NSString stringWithFormat:@"&%@=%@", [(NSString*)key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
		}    		
	}


    return [combinedDataString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];    
}
@end
