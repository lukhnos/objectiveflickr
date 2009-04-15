//
//  MainWindowController.h
//  RandomPublicPhoto
//
//  Created by Lukhnos D. Liu on 4/15/09.
//  Copyright 2009 Lithoglyph Inc.. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <ObjectiveFlickr/ObjectiveFlickr.h>

@interface MainWindowController : NSWindowController
{
	OFFlickrAPIContext *flickrContext;
	OFFlickrAPIRequest *flickrRequest;
	IBOutlet NSTextView *textView;
	IBOutlet WebView *webView;
}
- (IBAction)nextRandomPhotoAction:(id)sender;
@end
