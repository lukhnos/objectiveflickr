//
// OFAppDelegate.m
//
// Copyright (c) 2014 Lukhnos D. Liu (http://lukhnos.org)
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

#import "OFAppDelegate.h"
#import <objectiveflickr/ObjectiveFlickr.h>
#import "OFAPIKey.h"

@interface OFAppDelegate () <OFFlickrAPIRequestDelegate, NSURLSessionDownloadDelegate>
@property (nonatomic) OFFlickrAPIContext *flickrContext;
@property (nonatomic) OFFlickrAPIRequest *flickrRequest;
@property (nonatomic) NSString *nextPhotoTitle;
@property (nonatomic) NSURL *nextPhotoSourcePage;
@property (nonatomic) NSURLSession *urlSession;
@property (nonatomic) NSURLSessionDownloadTask *imageDownloadTask;
@property (weak, nonatomic) NSTimer *fetchTimer;
@end

@implementation OFAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.flickrContext = [[OFFlickrAPIContext alloc] initWithAPIKey:OFSampleAppAPIKey sharedSecret:OFSampleAppAPISharedSecret];
    self.urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    self.fetchTimer = [NSTimer scheduledTimerWithTimeInterval:7.0 target:self selector:@selector(handleTimer:) userInfo:nil repeats:YES];
    [self makeNextPhotoRequest];
}

- (void)makeNextPhotoRequest
{
    [self.imageLabel setStringValue:NSLocalizedString(@"Getting next photo…", nil)];

    self.flickrRequest = [[OFFlickrAPIRequest alloc] initWithAPIContext:self.flickrContext];
    self.flickrRequest.delegate = self;
    [self.flickrRequest callAPIMethodWithGET:@"flickr.photos.getRecent" arguments:@{@"per_page": @"1"}];
}

- (void)handleTimer:(NSTimer *)timer
{
    // NSURLSessionTaskStateRunning is 0, so a non-nil test for imageDownloadTask is needed
    if ([self.flickrRequest isRunning] || (self.imageDownloadTask && self.imageDownloadTask.state == NSURLSessionTaskStateRunning)) {
        return;
    }

    [self makeNextPhotoRequest];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)request didCompleteWithResponse:(NSDictionary *)response
{
    NSDictionary *photoDict = [[response valueForKeyPath:@"photos.photo"] objectAtIndex:0];
    NSString *title = [photoDict objectForKey:@"title"];
	if (![title length]) {
		title = NSLocalizedString(@"No Title", nil);
	}
    self.nextPhotoTitle = title;

    NSURL *photoSourcePage = [self.flickrContext photoWebPageURLFromDictionary:photoDict];
    self.nextPhotoSourcePage = photoSourcePage;

    self.flickrRequest = nil;

	NSURL *photoURL = [self.flickrContext photoSourceURLFromDictionary:photoDict size:OFFlickrLargeSize];
    self.imageDownloadTask = [self.urlSession downloadTaskWithURL:photoURL];
    [self.imageDownloadTask resume];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)request didFailWithError:(NSError *)error
{
    [self.imageView setImage:nil];
    [self.imageLabel setStringValue:NSLocalizedString(@"Error loading image", nil)];
    self.flickrRequest = nil;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    // If image is large, consider creating the image off the main queue
    NSImage *image = [[NSImage alloc] initWithData:[NSData dataWithContentsOfURL:location]];
    [self.imageView setImage:image];

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setAlignment:NSCenterTextAlignment];
    NSDictionary *attrs = @{NSParagraphStyleAttributeName: paragraphStyle,
                            NSLinkAttributeName: self.nextPhotoSourcePage,
                            NSForegroundColorAttributeName: [NSColor blueColor],
                            NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)};
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:self.nextPhotoTitle attributes:attrs];

    // https://developer.apple.com/library/mac/qa/qa1487/_index.html
    [self.imageLabel setAllowsEditingTextAttributes:YES];
    [self.imageLabel setSelectable:YES];
    [self.imageLabel setAttributedStringValue:attrString];

    NSError *error;
    BOOL result = [[NSFileManager defaultManager] removeItemAtURL:location error:&error];
    if (!result) {
        NSLog(@"Error removing temp file at: %@, error: %@", location, error);
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    [self.imageLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Getting image (%llu of %llu KB)", nil), totalBytesWritten / 1024, totalBytesExpectedToWrite / 1024]];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        [self.imageView setImage:nil];
    }
    
    self.imageDownloadTask = nil;
}
@end
