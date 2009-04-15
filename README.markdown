ObjectiveFlickr
===============

ObjectiveFlickr is a Flickr API framework designed for Mac and iPhone apps.


What's New in 2.0
=================

Version 2.0 is a complete rewrite, with design integrity and extensibility in
mind. Differences from 0.9.x include:

* The framework now builds under all major Apple platforms: Mac OS X 10.4,
  10.5, iPhone OS 2.2.x, and other beta version platforms to which I have 
  access. It also builds on both 32-bit and 64-bit platforms.
* Ordinary request and upload request are now unified into one 
  OFFlickrAPIRequest class
* 2.0 no longer depends on NSXMLDocument, which is not available in iPhone 
  SDK. It now maps Flickr's XML response into an NSDictionary using only 
  NSXMLParser, which is available on all Apple platforms.
* Image uploading employs temp file. This allows ObjectiveFlickr to operate
  in memory-constrained settings.
* Error reporting now uses NSError to provide more comprehensive information,
  especially error code and message from Flickr.
  
If you already use ObjectiveFlickr 0.9.x, the bad news is that 2.0 is not
backward compatible. The good news, though, is that it uses a different set
of class names. Some migration tips is offered near the end of this document.


What's Not (Yet) There
======================

There are of course quite a few to-do's:

* In-source API documentation
* No coverage test is yet done
* ObjectiveFlickr 0.9.x has a few convenient methods and tricks to simply 
  method calling; they are not ported here (yet, or will never be)


Quick Start: Example Apps You Can Use
=====================================

1. Check out the code from github:

        git clone git@github.com:lukhnos/objectiveflickr.git

2. Supply your own API key and shared secret. You need to copy
   `SimpleAPIKey.h.template` to `SimpleAPIKey.h`, and fill in the two
   macros there. If you don't have an API key, apply for yours at:

   > http://www.flickr.com/services/api/keys/apply/
   
   Make sure you have understood their terms and conditions.

3. Remember to make your API key a "web app", and set the *Callback URL*
   (not the *Application URL*!) to

        snapnrun://auth?
        
   Our example apps will rely on this for authentication.

4. Build and run SnapAndRun for iPhone. The project is located at 
   `Examples/SnapAndRun-iPhone`

5. Build and run RandomPublicPhoto for Mac. The project is at 
   `Examples/RandomPublicPhoto`


Adding ObjectiveFlickr to Your Project
======================================

Unlike Microsoft Visual Studio, Xcode does not shine in cross-project 
development. Fortunately you don't need to do this often. If anything fails, 
refer to our example apps for the project file structuring.

Adding ObjectiveFlickr to Your Mac App Project
----------------------------------------------

1. `Add ObjectiveFlickr.xcodeproj` to your Mac project (from Xcode menu 
   **Project > Add to Project...**)
2. On your app target, open the info window (using **Get Info** on the 
   target), then in the **General** tab, add `ObjectiveFlickr (framework)`
   to **Direct Dependencies**
3. Add a new **Copy Files** phase, and choose **Framework** for the 
   **Destination** (in its own info window)
4. Drag `ObjecitveFlickr.framework` from the Groups & Files panel in Xcode 
   (under the added `ObjectiveFlickr.xcodeproj`) to the newly created **Copy 
   Files** phase
5. Drag `ObjecitveFlickr.framework` once again to the target's **Linked Binary 
   With Libraries** group
6. Open the Info window of your target again. Set **Configuration** to **All 
   Configurations**, then in the **Framework Search Paths** property, add 
   `$(TARGET_BUILD_DIR)/$(FRAMEWORKS_FOLDER_PATH)`
7. Use #import <ObjectiveFlickr/ObjectiveFlickr.h> in your project

Adding ObjectiveFlickr to Your iPhone App Project
-------------------------------------------------

Because iPhone SDK does not allow dynamically linked frameworks and bundles, we need to link against ObjectiveFlickr statically.

1. `Add ObjectiveFlickr.xcodeproj` to your Mac project (from Xcode menu 
   **Project > Add to Project...**)
2. On your app target, open the info window (using **Get Info** on the 
   target), then in the **General** tab, add `ObjectiveFlickr (library)` to 
   **Direct Dependencies**
3. Drag `ObjecitveFlickr.framework` once again to the target's **Linked Binary 
   With Libraries** group
4. Open the Info window of your target again. Set **Configuration** to **All 
   Configurations**, then in the **Header Search Paths** property, add these 
   two paths, separately:

        <OF root>/Source
        <OF root>/LFWebAPIKit
            
   `<OF root>` is where you checked out ObjectiveFlickr.
5. Use #import "ObjectiveFlickr.h" in your project


Key Ideas and Basic Usage
=========================

***ObjectiveFlickr is an asynchronous API.*** Because of the nature of GUI 
app, all ObjectiveFlickr requests are asynchronous. You make a request, then 
ObjectiveFlickr calls back your delegate methods and tell you if a request 
succeeds or fails.

***ObjectiveFlickr is a minimalist framework.*** The framework has essentially
only two classes you have to deal with: `OFFlickrAPIContext` and
`OFFlickrAPIRequest`. Unlike many other Flickr API libraries, ObjectiveFlickr 
does *not* have classes like FlickrPhoto, FlickrUser, FlickrGroup or 
whathaveyou. You call a Flickr method, like `flickr.photos.getInfo`, and get back a dictionary (hash or map in other languages) containing the key-value 
pairs of the result. The result is *directly mapped from Flickr's own 
XML-formatted response*. Because they are already *structured data*, 
ObjectiveFlickr does not  translate further into other object classes. 

Because of the minimalist design, you also need to have basic understanding of
***how Flickr API works***. Refer to http://www.flickr.com/services/api/ for 
the details. But basically, all you need to know is the methods you want to
call, and which XML data (the key-values) Flickr will return.

Typically, to develop a Flickr app for Mac or iPhone, you need to follow the following steps:

1. Get a Flickr API key at http://www.flickr.com/services/api/keys/apply/
2. Create an OFFlickrAPIContext object

        OFFlickrAPIContext *context = [[OFFlickrAPIContext alloc] initWithAPIKey:YOUR_KEY sharedSecret:YOUR_SHARED_SECRET];

3. Create an OFFlickrAPIRequest object where appropriate, and set the delegate

        OFFlickrAPIRequest *request = [[OFFlickrAPIRequest alloc] initWithAPIContext:context];
        
        // set the delegate, here we assume it's the controller that's creating the request object
        [request setDelegate:self];
        
4. Implement the delegate methods.

        - (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary;
        - (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)inError;
        - (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest imageUploadSentBytes:(NSUInteger)inSentBytes        

    All three methods are optional ("informal protocol" in old Objective-C 
    speak; optional protocol methods in newspeak). *Nota bene*: If you
    are using Mac OS X 10.4 SDK, or if you are using 10.5 SDK but targeting
    10.4, then the delegate methods are declared as informal protocols.
    In all other cases (OS X 10.5 and above or iPhone apps), you need to
    specify you are adopting the OFFlickrAPIRequestDelegate protocol. *E.g.*:
    
        @interface MyViewController : UIViewController (OFFlickrAPIRequestDelegate)


5. Call the Flickr API methods you want to use. Here are a few examples.

    Calling `flickr.photos.getRecent` with the argument `per_page` = `1`:
    
        [request callAPIMethodWithGET:@"flickr.photos.getRecent" arguments:[NSDictionary dictionaryWithObjectsAndKeys:@"1", @"per_page", nil]]
        
    Quite a few Flickr methods require that you call with HTTP POST
    (because those methods write or modify user data):

        [request callAPIMethodWithPOST:@"flickr.photos.setMeta" arguments:[NSDictionary dictionaryWithObjectsAndKeys:photoID, @"photo_id", newTitle, @"title", newDescription, @"description", nil]];

6. To upload a picture, create an NSInputStream object from a file path
   or the image data (NSData), then make the request. Here in the example
   we assume we already have obtained the image data in JPEG, and we set
   make private the uploaded picture:
   
        NSInputStream *imageStream = [NSInputStream inputStreamWithData:imageData]
        [request uploadImageStream:imageStream suggestedFilename:@"Foobar.jpg" MIMEType:@"image/jpeg" arguments:[NSDictionary dictionaryWithObjectsAndKeys:@"0", @"is_public", nil]];
   

   Upload progress will be reported in the delegate
   `flickrAPIRequest:imageUploadSentBytes:totalBytes:`
      
7. Handle the response or error in the delegate methods. If an error
   occurs, an NSError object is passed to the error-handling delegate 
   method. If the error object's domain is `OFFlickrAPIReturnedErrorDomain`,
   then it's a server-side error. You can refer to Flickr's API documentation
   for the meaning of the error. If the domain is
   `OFFlickrAPIRequestErrorDomain`, it's client-side error, usually caused
   by lost network connection or transfer timeout.
   
   We will now talk about the response.

   
How Flickr's XML Response Are Mapped Back
=========================================

Flickr's default response format is XML. You can opt for JSON. Whichever
format you choose, the gist is that *they are already structured data*.
When I first started designing ObjectiveFlickr, I found it unnecessary to
create another layer of code that maps those data to and from "native"
objects. So we don't have things like `OFFlickrPhoto` or `OFFlickrGroup`.
In essence, when an request object receives a response, it maps the XML
into a data structure consisting of NSDictionary's, NSArray's and 
NSString's. In Apple speak, this is known as "property list". And we'll
use that term to describe the mapped result. You then read out in the property
list the key-value pairs you're interested in.

ObjectiveFlickr uses the XML format to minimize dependency. It parses the
XML with NSXMLParser, which is available on all Apple platforms. It maps
XML to property list following the three simple rules:

1. All XML tag properties are mapped to NSDictionary key-value pairs
2. Text node (e.g. `<photoid>12345</photoid>`) is mapped as a dictionary
   containing the key `OFXMLTextContentKey` (a string const) with its value
   being the text content.
3. ObjectiveFlickr knows when to translate arrays. We'll see how this is 
   done now.
   
So, for example, this is a sample response from flickr.auth.checkToken   

    <?xml version="1.0" encoding="utf-8" ?>
    <rsp stat="ok">
    <auth>
    	<token>aaaabbbb123456789-1234567812345678</token>
    	<perms>write</perms>
    	<user nsid="00000000@N00" username="foobar" fullname="blah" />
    </auth>
    </rsp>
 
Then in your `flickrAPIRequest:didCompleteWithResponse:` delegate method,
if you dump the received response (an NSDictionary object) with NSLog,
you'll see something like (extraneous parts omitted):

    {
        auth ={
            perms = { "_text" = write };
            token = { "_text" = "aaaabbbb123456789-1234567812345678"; };
            user = {
                fullname = "blah";
                nsid = "00000000@N00";
                username = foobar;
            };
        };
        stat = ok;
    }
 
So, say, if we are interested in the retrieved auth token, we can do this:

    NSString *authToken = [[inResponseDictionary valueForKeyPath:@"auth.token"] textContent];
    
Here, our own `-[NSDictionary textContent]` is simply a convenient method
that is equivalent to calling `[authToken objectForKey:OFXMLTextContentKey]`
in our example.

Here is another example returned by `flickr.photos.getRecent`:

    <?xml version="1.0" encoding="utf-8" ?>
    <rsp stat="ok">
    <photos page="1" pages="334" perpage="3" total="1000">
    	<photo id="3444583634" owner="37096380@N08" secret="7bbc902132" server="3306" farm="4" title="studio_53_1" ispublic="1" isfriend="0" isfamily="0" />
    	<photo id="3444583618" owner="27122598@N06" secret="cc76db8cf8" server="3327" farm="4" title="IMG_6830" ispublic="1" isfriend="0" isfamily="0" />
    	<photo id="3444583616" owner="26073312@N08" secret="e132988dc3" server="3376" farm="4" title="Cidade Baixa" ispublic="1" isfriend="0" isfamily="0" />
    </photos>
    </rsp>
    
And the mapped property list looks like:
    
    {
        photos = {
            page = 1;
            pages = 334;
            perpage = 3;
            photo = (
                {
                    farm = 4;
                    id = 3444583634;
                    isfamily = 0;
                    isfriend = 0;
                    ispublic = 1;
                    owner = "37096380@N08";
                    secret = 7bbc902132;
                    server = 3306;
                    title = "studio_53_1";
                },
                {
                    farm = 4;
                    id = 3444583618;
                    /* ... */
                },
                {
                    farm = 4;
                    id = 3444583616;
                    /* ... */
                }
            );
            total = 1000;
        };
        stat = ok;
    }

ObjectiveFlickr knows to translate the enclosed <photo> tags in the plural
<photos> tag into an NSArray. So if you want to retrieve the second photo
in the array, you can do this:

    NSDictionary *photoDict = [[inResponseDictionary valueForKeyPath:@"photos.photo"] objectAtIndex:1];

Then, with two helper methods from `OFFlickrAPIContext`, you can get the
static photo source URL and the photo's original web page URL:

    NSURL *staticPhotoURL = [flickrContext photoSourceURLFromDictionary:photoDict size:OFFlickrSmallSize];
    NSURL *photoSourcePage = [flickrContext photoWebPageURLFromDictionary:photoDict];

Do remember that Flickr requires you present a link to the photo's web page
wherever you show the photo in your app. So design your UI accordingly.


Design Patterns and Tidbits
===========================

Design Your Own Trampolines
---------------------------

`OFFlickrAPIRequest` has a `sessionInfo` property that you can use to provide
state information of your app. However, it will soon become tedious to write
tons of `if`-`else`s in the delegate methods. My experience is that I design
a customized "session" object with three properties: delegate (that doesn't
have to be the originator of the request), selector to call on completion,
selector to call on error. Then the delegate methods for `OFFlickrAPIRequest`
simply dispatches the callbacks according to the session object.

If your controller calls a number of Flickr methods or involves multiple
stages/states, this design pattern will be helpful.

Thread-Safety
-------------

Each OFFlickrAPIRequest object can be used in the thread on which it is created. Do not pass them across threads. Delegate methods are also called in the thread in which the request object is running.

CFNetwork-Only
--------------

ObjectiveFlickr uses LFHTTPRequest, which uses only the CFNetwork stack.
NSURLConnection is reported to have its own headaches. On the other hand,
LFHTTPRequest does not handle non-HTTP URLs (it does handle HTTPS with
a catch: on iPhone you cannot use untrusted root certs) and does not do
HTTP authentication. It also does not manage caching. For web API
integration, however, LFHTTPRequest provides a lean way of making and
managing requests.


History
=======

ObjectiveFlickr was first released in late 2006. The previous version, 0.9.x,
has undergone one rewrite and is hosted on [Google 
Code](http://code.google.com/p/objectiveflickr). It also has a Ruby version
available as a [Ruby gem](http://rubyforge.org/frs/?group_id=2698).

The present rewrite derives from the experiences that I have had in
developing Mac and iPhone products (I run my own company, [Lithoglyph](lithoglyph.com)). It's a great learning process.


Acknowledgements
================

Many people have given kind suggestions and directions to the development
of ObjectiveFlickr. And there are a number of Mac apps that use it. I'd like
to thank Mathieu Tozer, Tristan O'Tierney, Christoph Priebe, Yung-Lun Lan, 
and Pierre Bernard for the feedbacks that eventually lead to the framework's
present design and shape.


Copyright and Software License
==============================

ObjectiveFlickr Copyright (c) 2006-2009 Lukhnos D. Liu.
LFWebAPIKit Copyright (c) 2007-2009 Lukhnos D. Liu and Lithoglyph Inc.

One test in LFWebAPIKit (`Tests/StreamedBodySendingTest`) makes
use of [Google Toolbox for Mac](
http://code.google.com/p/google-toolbox-for-mac/), Copyright (c) 2008 Google Inc. Refer to `COPYING.txt` in the directory for the full text of the Apache License, Version 2.0, under which the said software is licensed.

Both ObjectiveFlickr and LFWebAPIKit are released under the MIT license,
the full text of which is printed here as follows. You can also 
find the text at: http://www.opensource.org/licenses/mit-license.php

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Contact
=======

* lukhnos {at} lukhnos {dot} org
* http://lukhnos.org (English)
* http://lukhnos.org/blog/zh (Traditional Chinese)
* http://lithoglyph.com (My company)
