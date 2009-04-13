//
// main.m
//
// Copyright (c) 2007-2009 Lithoglyph Inc. All rights reserved.
//

#import "ObjectiveFlickr.h"
#import "SampleAPIKey.h"

@interface SimpleDelegate : NSObject <OFFlickrAPIRequestDelegate>
@end

@implementation SimpleDelegate
- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary
{
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)error
{
}
@end


int main(int argc, char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if (argc < 2) {
		fprintf(stderr, "usage: flickr-list-public-photos <Flickr user NSID>\n");
		return 1;
	}
	
	NSString *userID = [NSString stringWithUTF8String:argv[1]];
	
	SimpleDelegate *delegate = [[SimpleDelegate alloc] init];
	OFFlickrAPIContext *context = [[OFFlickrAPIContext alloc] initWithAPIKey:OBJECTIVE_FLICKR_SAMPLE_API_KEY sharedSecret:OBJECTIVE_FLICKR_SAMPLE_API_SHARED_SECRET];
	OFFlickrAPIRequest *request = [[OFFlickrAPIRequest alloc] initWithAPIContext:context];

	[request setDelegate:delegate];
	[request callAPIMethodWithGET:@"flickr.people.getPublicPhotos" arguments:[NSDictionary dictionaryWithObjectsAndKeys:userID, @"user_id", nil]];
									   
	[request release];
	[context release];
	[delegate release];
								   	
	[pool drain];
	return 0;
}
