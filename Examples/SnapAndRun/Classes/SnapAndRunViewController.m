//
// SnapAndRunViewController.m
//
// Copyright (c) 2009 Lukhnos D. Liu (http://lukhnos.org)
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

#import "SnapAndRunViewController.h"
#import "SnapAndRunAppDelegate.h"

NSString *kGetFrobStep = @"kGetFrobStep";
NSString *kGetAuthTokenStep = @"kGetFrobStep";
NSString *kGetUserInfoStep = @"kGetUserInfoStep";
NSString *kSetImagePropertiesStep = @"kSetImagePropertiesStep";
NSString *kUploadImageStep = @"kUploadImageStep";

@implementation SnapAndRunViewController
- (void)viewDidUnload
{
    self.flickrRequest = nil;
    self.imagePicker = nil;
    
    self.authorizeButton = nil;
    self.authorizeDescriptionLabel = nil;
    self.snapPictureButton = nil;
    self.snapPictureDescriptionLabel = nil;
}

- (void)dealloc
{
    [self viewDidUnload];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Snap and Run";
	
	if ([[SnapAndRunAppDelegate sharedDelegate].flickrContext.authToken length]) {
		authorizeButton.enabled = NO;
	}
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark Actions

- (IBAction)snapPictureAction
{
    [self presentModalViewController:self.imagePicker animated:YES];
}

- (IBAction)authorizeAction
{
    self.flickrRequest.sessionInfo = kGetFrobStep;
    [self.flickrRequest callAPIMethodWithGET:@"flickr.auth.getFrob" arguments:nil];
}

#pragma mark OFFlickrAPIRequest delegate methods
- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary
{
    NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, inRequest.sessionInfo, inResponseDictionary);
    
    if (inRequest.sessionInfo == kGetFrobStep) {
        NSLog(@"Frob: %@", [[inResponseDictionary valueForKeyPath:@"frob"] textContent]);
        
        NSURL *loginURL = [[SnapAndRunAppDelegate sharedDelegate].flickrContext loginURLFromFrobDictionary:inResponseDictionary requestedPermission:OFFlickrWritePermission];
        [[UIApplication sharedApplication] openURL:loginURL];
    }
	else if (inRequest.sessionInfo == kUploadImageStep) {
		snapPictureButton.enabled = YES;
		snapPictureDescriptionLabel.text = @"Done";
		
		[UIApplication sharedApplication].idleTimerDisabled = NO;		
	}
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)inError
{
    NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, inRequest.sessionInfo, inError);
	if (inRequest.sessionInfo == kUploadImageStep) {
		snapPictureButton.enabled = YES;
		snapPictureDescriptionLabel.text = @"Failed";
		
		[UIApplication sharedApplication].idleTimerDisabled = NO;
	}
	else {
		[[[[UIAlertView alloc] initWithTitle:@"API Failed" message:[inError description] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] autorelease] show];
	}
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest imageUploadSentBytes:(NSUInteger)inSentBytes totalBytes:(NSUInteger)inTotalBytes
{
	snapPictureDescriptionLabel.text = [NSString stringWithFormat:@"%lu/%lu", inSentBytes, inTotalBytes];
}


#pragma mark UIImagePickerController delegate methods
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissModalViewControllerAnimated:YES];
}

#ifndef __IPHONE_3_0
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    NSDictionary *editingInfo = info;
#else
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo
{
#endif

    [self dismissModalViewControllerAnimated:YES];

    NSData *JPEGData = UIImageJPEGRepresentation(image, 1.0);
    
	snapPictureButton.enabled = NO;
	snapPictureDescriptionLabel.text = @"Uploading";
	
    self.flickrRequest.sessionInfo = kUploadImageStep;
    [self.flickrRequest uploadImageStream:[NSInputStream inputStreamWithData:JPEGData] suggestedFilename:@"Snap and Run Demo" MIMEType:@"image/jpeg" arguments:[NSDictionary dictionaryWithObjectsAndKeys:@"0", @"is_public", nil]];
	
	[UIApplication sharedApplication].idleTimerDisabled = YES;
}

#pragma mark Accesors

- (OFFlickrAPIRequest *)flickrRequest
{
    if (!flickrRequest) {
        flickrRequest = [[OFFlickrAPIRequest alloc] initWithAPIContext:[SnapAndRunAppDelegate sharedDelegate].flickrContext];
        flickrRequest.delegate = self;
    }
    
    return flickrRequest;
}

- (UIImagePickerController *)imagePicker
{
    if (!imagePicker) {
        imagePicker = [[UIImagePickerController alloc] init];
        imagePicker.delegate = self;
		
		if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
			imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
		}
    }
    return imagePicker;
}

#ifndef __IPHONE_3_0
- (void)setView:(UIView *)view
{
	if (view == nil) {
		[self viewDidUnload];
	}
	
	[super setView:view];
}
#endif

@synthesize flickrRequest;
@synthesize imagePicker;

@synthesize authorizeButton;
@synthesize authorizeDescriptionLabel;
@synthesize snapPictureButton;
@synthesize snapPictureDescriptionLabel;
@end
