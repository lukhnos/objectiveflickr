ObjectiveFlickr
===============

ObjectiveFlickr is a Flickr API framework for Objective-C. I first created the framework in 2006 and have made it available on [Google Code](http://code.google.com/p/objectiveflickr).

Since then a lot has been changed, and I have also learned a lot from designing a framework.

The code hosted now on GitHub is a complete rewrite. I'm in the beginning of it but am targeting to do the things right. Most importantly, the framework will compile on all of the major Apple platforms: Mac OS X 10.4, 10.5, iPhone SDK 2, and others.

This new framework breaks from the past. It now uses NSError for better error reporting. It uses NSXMLParser to ensure minimum XML parser dependency (I didn't use JSON for the same reason; it would have required external libraries).

For the time being, it's not a complete framework. Authorization, static URL provisioning and uploading are lacking. But I'm actively working on it, so stay tuned!

My email address is lukhnos {at} lukhnos {dot} org

Enjoy!
