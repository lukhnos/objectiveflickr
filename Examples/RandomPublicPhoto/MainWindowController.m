//
//  MainWindowController.m
//  RandomPublicPhoto
//
//  Created by Lukhnos D. Liu on 4/15/09.
//  Copyright 2009 Lithoglyph Inc.. All rights reserved.
//

#import "MainWindowController.h"
#import "SampleAPIKey.h"

@implementation MainWindowController
- (void)dealloc
{
	[flickrContext release];
	[flickrRequest release];
	[super dealloc];
}

- (void)awakeFromNib
{
	flickrContext = [[OFFlickrAPIContext alloc] initWithAPIKey:OBJECTIVE_FLICKR_SAMPLE_API_KEY sharedSecret:OBJECTIVE_FLICKR_SAMPLE_API_SHARED_SECRET];
	flickrRequest = [[OFFlickrAPIRequest alloc] initWithAPIContext:flickrContext];
	[flickrRequest setDelegate:self];
	[self nextRandomPhotoAction:self];
	
	[[NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(nextRandomPhotoAction:) userInfo:nil repeats:YES] fire];
	
	[webView setDrawsBackground:NO];
	
	[[self window] center];
}

- (IBAction)nextRandomPhotoAction:(id)sender
{
	if (![flickrRequest isRunning]) {
		[flickrRequest callAPIMethodWithGET:@"flickr.photos.getRecent" arguments:[NSDictionary dictionaryWithObjectsAndKeys:@"1", @"per_page", nil]];
	}
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary
{
	NSDictionary *photoDict = [[inResponseDictionary valueForKeyPath:@"photos.photo"] objectAtIndex:0];
	
	NSString *title = [photoDict objectForKey:@"title"];
	if (![title length]) {
		title = @"No title";
	}
	
	NSURL *photoSourcePage = [flickrContext photoWebPageURLFromDictionary:photoDict];
	NSDictionary *linkAttr = [NSDictionary dictionaryWithObjectsAndKeys:photoSourcePage, NSLinkAttributeName, nil];
	NSMutableAttributedString *attrString = [[[NSMutableAttributedString alloc] initWithString:title attributes:linkAttr] autorelease];	
	[[textView textStorage] setAttributedString:attrString];

	NSURL *photoURL = [flickrContext photoSourceURLFromDictionary:photoDict size:OFFlickrSmallSize];
	NSString *htmlSource = [NSString stringWithFormat:
							@"<html>"
							@"<head>"
							@"  <style>body { margin: 0; padding: 0; } </style>"
							@"</head>"
							@"<body>"
							@"  <table border=\"0\" align=\"center\" valign=\"center\" cellspacing=\"0\" cellpadding=\"0\" height=\"240\">"
							@"    <tr><td><img src=\"%@\" /></td></tr>"
							@"  </table>"
							@"</body>"
							@"</html>"
							, photoURL];
	
	[[webView mainFrame] loadHTMLString:htmlSource baseURL:nil];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)inError
{
}
@end
