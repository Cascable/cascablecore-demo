# Getting Started With CascableCore

CascableCore is a framework for connecting to and working with WiFi-enabled cameras from Canon, Fujifilm, Nikon, Olympus, Panasonic, and Sony.

This document is a technical quick-start guide, giving an overview of the framework's overall use and some tips and tricks for getting started efficiently.

Code samples are in Objective-C, but CascableCore is fully compatible with Swift. For more information on specific APIs, see CascableCore's API documentation. 

## A Note on Thread Safety

CascableCore manages internal threads as needed to run all camera communication and processing work in the background, keeping the main thread free for your application's UI to run smoothly. 

However, CascableCore is _not_ thread safe. It expects all calls to be made to it from the main thread of your application, and all block callbacks will be delivered on the main thread unless documented otherwise or unless the API in question takes an explicit delivery queue.

## Camera Discovery

In order to get going, you'll need to _discover_ the user's camera on the local network. To do this, use the `CBLCameraDiscovery` class.

```objc
CBLCameraDiscovery *discovery = [CBLCameraDiscovery sharedInstance];
```

`CBLCameraDiscovery` can notify you of new cameras through delegate method calls, through a block observer, or through key-value observing of the `availableCameras` property. Make sure you call `beginSearching` after registering your observer! 

```objc
[discovery addDevicesChangedObserver:^(NSArray *cameras) {

    // This block will get called whenever the available cameras list changes.
    NSLog(@"Available cameras: %@", cameras);

    // Let's just connect to the first camera we find.
    // Typically, it's best to stop searching when we find a camera.
    if (cameras.count > 0) {
        [self connectToCamera:cameras.firstObject];
        [discovery stopSearching];
    }
}];

// Make sure to start searching!
[discovery beginSearching]; 
```

`CBLCameraDiscovery` will handle changes in connectivity caused by entering the background, disconnecting from and connecting to Wi-Fi networks, etc.

Once you've found a camera to connect to, typically it's best to stop camera discovery by calling `CBLCameraDiscovery`'s `stopSearching` method, since discovery has a small but constant drain on battery and network resources. If you do choose to keep discovery running while connected to a camera, be aware that it's normal behaviour for a camera to disappear from the discovered cameras list while you're still connected to it — some cameras will shut down their network discovery broadcast once connected to.

#### Important iOS Simulator Notes

On Mac OS and iOS device targets, camera discovery works out-of-the-box. However, on the iOS Simulator, it needs help to discover certain cameras. When running your app in the iOS Simulator, there are two launch arguments you may need to pass to your application (which will in turn be picked up by CascableCore):

- Pass the network interface to discover cameras through using the `CBLNetworkConfigurationSimulatorWiFiInterfaceOverride` launch argument. You can find your Mac's network interface names in the Network Utility application. For example:

    `-CBLNetworkConfigurationSimulatorWiFiInterfaceOverride en1`.

- Additionally, if you're working with Fujifilm cameras, you need to tell CascableCore the name of the camera's Wi-Fi network using the `CBLNetworkConfigurationSimulatorSSIDOverride` argument. For example:

    `-CBLNetworkConfigurationSimulatorSSIDOverride "FUJIFILM-X-T2-ABCD"`

These arguments can be added to the "Arguments" tab of your project's scheme editor. 

<p align="center">
<img src="Documentation%20Images/arguments.png" width="930">
</p>

Again, these parameters are only needed when working in the iOS Simulator.

## Connecting To and Disconnecting From Cameras

Once you've discovered a camera, you'll probably want to connect to it! 

It's important to be aware that sometimes, cameras will halt the incoming connection process to ask the user something. This typically happens if the camera's connection workflow requires 'pairing' with apps.

When this occurs, CascableCore invokes what's called a "user intervention callback". When this is called, it's important to display UI in your app telling the user that they need to look at their camera and follow any on-screen instructions. Once the camera continues with the connection, CascableCore will call the user intervention callback again letting you know that it's safe to hide the UI. 

In our own apps, we display a dialog like this:

<p align="center">
<img src="Documentation%20Images/user-intervention-dialog-example.png" width="301">
</p>

```objc
CBLCameraConnectionUserInterventionBlock userIntervention = 
    ^(BOOL displayUI, _Nullable dispatch_block_t cancelConnectionBlock) 
{
    if (displayUI) {
        // If we wanted to cancel the connection at this point, call the passed cancelConnectionBlock().
        [self showLookAtCameraDialog];
    } else {
        // The user intervention callback will never be invoked with displayUI set to NO without
        // first being invoked with it set to YES.
        [self hideLookAtCameraDialog];
    }
}
```

When the connection to the camera completes (or fails), the connection completion block will be called. You can also observe the status of the `connected` and `connectionStatus` properties.

```objc
id <CBLCamera> camera = …;

[camera connectWithClientName:@"My Awesome App" 
           completionCallback:^(NSError *error, NSArray *warnings) {

    if (error != nil) {
        if (error.code == CBLErrorCodeCancelledByUser) {
            // If the connection was cancelled by the user, there's no need to throw error UI.
            [self handleConnectionCancelledByUser];
        } else if (error.code == CBLErrorCodeCameraNeedsSoftwareUpdate) {
            // The camera can't be connected to until the camera has a software update.
            [self showRequiresSoftwareUpdateConnectionError];
        } else {
            [self showMiscConnectionError];
        }
    } else {
        // If error is nil, the connection was successful.
        [self handleSuccessfulConnection];
    }

} userInterventionCallback:userIntervention];
```

Disconnecting from a connected camera is simpler. If you're holding the main thread of your application during disconnect (for example, disconnecting nicely from a camera while the application quits), you can request the callback from this call be delivered on a background queue to ease threading semantics.

```objc
id <CBLCamera> camera = …;

[camera disconnect:^(NSError *error) {
    NSLog(@"Disconnected!");
} callbackQueue:dispatch_get_main_queue()];
```

#### Handling Unexpected Disconnects

It's a reasonably common occurrance that the camera can disconnect unexpectedly - for example, the camera's battery can run out of power, or the user can move out of Wi-fi range, etc. 

To handle this correctly, add a Key-Value Observer to your camera's `connectionState` property, and in your handler for this, check the camera's `disconnectionWasExpected` property.

```objc
id <CBLCamera> camera = …;
[camera addObserver:self keyPath:@"connectionState" options:0 context:myKvoContext];

// KVO Handler:
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id <NSObject>)object change:(NSDictionary *)change context:(void *)context {

    if ([keyPath isEqualToString:@"connectionState"]) {
        if (self.camera.connectionState == CBLCameraConnectionStateNotConnected &&
            !self.camera.disconnectionWasExpected) {
            // This was an unexpected disconnect!
            [self showUnexpectedDisconnectUI];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}
```

## Available Functionality

Cameras are all different, and the functionality differences between them can be significant enough to warrant changes in your application's UI. 

`CBLCamera` provides the `supportedFunctionality` property to assist with this, containing a bitmask of the connected camera's supported functionality. It also has the helper method `supportsFunctionality:`. 

**Note:** The value of the `supportedFunctionality` is only valid once the camera has been successfully connected to.

```objc
if ([camera supportsFunctionality:CBLCameraFileDeletionFunctionality]) {
    // Show a "delete file" button.
}
```

## Available Command Categories

Many cameras need to be put into special "modes" before certain commands will work. CascableCore supports two different modes:

- `CBLCameraAvailableCommandCategoryRemoteShooting` for commands related to shooting images and streaming the camera's live view image.

- `CBLCameraAvailableCommandCategoryFilesystemAccess` for commands related to accessing images on the the camera's filesystem.

It's important to note that several cameras support multiple modes at once. Therefore, a simple equality check is not sufficient. `CBLCamera` provides the `currentCommandCategoriesContainsCategory:` method to assist:

```objc
id <CBLCamera> camera = …;

if ([camera currentCommandCategoriesContainsCategory:CBLCameraAvailableCommandCategoryRemoteShooting]) {
    // Ready for shooting!
}
```

To switch the camera to a different mode, use the `supportsCommandCategories:` and `setCurrentCommandCategories:` methods. 

```objc
id <CBLCamera> camera = …;
CBLCameraAvailableCommandCategory category = CBLCameraAvailableCommandCategoryFilesystemAccess;

if ([camera supportsCommandCategories:category]) {
    [camera setCurrentCommandCategories:category callback:^(NSError *error) {
        if (error != nil) {
            NSLog(@"An error occurred while switching command categories: %@", error);
        } else {
            // Success!
        }
    }];
}
```

Setting a camera's command categories to the value they're already at is a harmless operation, which can be used to simplify application logic — instead of checking the current command categories and only setting they if they're incorrect, you can simply set them and continue.

## Live View and Focus Geometry

**Note:** Many cameras require live view to be enabled for shooting to work correctly. Some cameras require live view to be enabled for *anything* to work correctly — in such cases, CascableCore may enable live view automatically.

To start live view, use `CBLCamera`'s `beginLiveViewStreamWithDelivery:deliveryQueue:terminationHandler:` method. Frames will be repeatedly delivered to the block given to the `delivery` parameter, and when live view terminates the `terminationHandler` block will be called.

```objc

CBLCameraLiveViewFrameDelivery delivery = ^(id<CBLCameraLiveViewFrame> frame, dispatch_block_t completionHandler) {

    // The live view image frame's image is always in the landscape orientation, even if the camera is rotated.
    // This is because focus areas etc. are always relative to the landscape orientation (i.e., when you rotate
    // the camera, the focus points rotate with it, so they're always relative to the landscape orientation).
    // If the camera supports live view orientation, the frame's orientation property may be something
    // other than CBLCameraLiveViewFrameOrientationLandscape, and you may choose to rotate your UI.

    // Here, however, we'll just display the image as-is.
    self.liveViewImageView.image = frame.image;

    // We must call the completion handler once we're ready for more live view frames. Since we want a nice, smooth
    // image, we'll call the completion handler without delay.
    completionHandler();
};

[self.camera beginLiveViewStreamWithDelivery:delivery
                               deliveryQueue:dispatch_get_main_queue()
                          terminationHandler:^(CBLCameraLiveViewTerminationReason reason, NSError * error) {
                              if (error != nil) {
                                  NSLog(@"%@: Live view terminated with error: %@", THIS_FILE, error);
                              } else {
                                  NSLog(@"%@: Terminated live view", THIS_FILE);
                              }
                          }];

```

It's important to bear in mind that a camera's focus points will be relative to a given coordinate system which will certainly be different to your application's views, and often different to the size of the image given by the camera. In some cases, the aspect ratio may not even match — some Panasonic cameras place AF areas in a square of `1000x1000` even if the viewfinder image is at an aspect ratio of `4:3` or even `16:9`.

To assist with this, `CBLCameraLiveViewFrame` objects contain a numer of geometry transformation methods that perform the relevant math for you. Otherwise, you can get the camera's coordinate space using `CBLCameraLiveViewFrame`'s `aspect` property.

```objc
// In this example, we want to render the camera's AF areas on top of the
// image view showing the live view image. However, the AF areas must be
// translated from the camera's coordinate system to the image view's
// coordinate system.

// The image view must be sized so the live view image fills it 
// completely for this logic to work correctly.
UIImageView *imageView = …;
id <CBLCameraLiveViewFrame> liveViewFrame = …;

// Put the camera's live view image into the image view.
imageView.image = liveViewFrame.image;

// We're going to add subviews to show the camera's active AF area(s).
// However, AF areas are relative to the camera's own coordinate system.
// Luckily, CBLCameraLiveViewFrame has methods to translate these to our view coordinates.
for (id <CBLCameraLiveViewAFArea> afArea in liveViewFrame.flexiZoneAFRects) {

    if (!afArea.active) {
        // Skip inactive areas
        continue;
    }

    CGRect afFrame = [liveViewFrame translateSubRectOfAspect:afArea.rect
                                             toSubRectOfRect:imageView.bounds];

    UIView *afRect = [UIView new];
    afRect.frame = afFrame;
    afView.layer.borderColor = [UIColor redColor];
    afView.layer.borderWidth = 2.0;
    [imageView addSubView:afRect]; 
}
```

```objc
// In this example, a tap gesture recognizer has been added to the live view
// image view in order to allow the user to tap-to-focus on the image. However,
// the tap location must be translated to the camera's coordinate system first.

-(void)afTap:(UITapGestureRecognizer *)sender {
    
    id <CBLCamera> camera = …;
    id <CBLCameraLiveViewFrame> liveViewFrame = …;

    if (!camera.supportsTouchAF || CGSizeEqualToSize(liveViewFrame.aspect, CGSizeZero)) {
        // It makes sense to guard against cameras that don't support touch AF.
        return;
    }

    CGPoint tapLocation = [sender locationInView:self.imageView];

    // The tap location must be translated to the camera's own coodinate system.
    CGPoint translatedPoint = [liveViewFrame pointInAspectTranslatedFromPoint:tapLocation
                                                                       inRect:self.imageView.bounds];

    // Now it's been translated, we can send the point to the camera.
    [camera touchAFAtPoint:translatedPoint callback:^(NSError *error) {
        // CBLErrorCodeAutoFocusFailed means that autofocus failed for a "normal" reason,
        // for example the camera is too close to the object or the lens cap was left on.
        if (error != nil && error.code != CBLErrorCodeAutoFocusFailed) {
            NSLog(@"An error occurred while trying to autofocus: %@", error);
        }
    }];
}
```

## Shooting Images and Shot Preview

To shoot an image, you need to engage autofocus, engage the shutter, release the shutter, then release autofocus using `CBLCamera`'s, `engageAutoFocus:`, `engageShutter:`, `disengageShutter:` and `disengageAutoFocus:` methods. Please note that these methods are all asynchronous (like most other requests).

Alternatively, if you don't need fine-grained control, you can use the helper method `invokeOneShotShutterExplicitlyEngagingAutoFocus:completionCallback:`.

To access shot photos, you need to switch the camera to the `CBLCameraAvailableCommandCategoryFilesystemAccess` command category and iterate the filesystem in search of the new photo. However, if a lower-resolution (typically 2-3 megapixel) preview is sufficient, CascableCore provides shot preview support for most cameras.

Shot preview delivers a preview of a photo shortly after it is taken, without needing to switch away from the remote shooting command category and disabling live view etc. As this preview is delivered entirely in the camera's desired timeframe, you must register an observer block for shot preview:

```objc
id <CBLCamera> camera = …;

// You only need to register for shot preview once in the camera's 
// lifespan — the callback will be called repeatedly as required.

[camera addShotPreviewObserver:^(id <CBLCameraShotPreviewDelivery> shotPreview) {
    // When a shot preview delivery object is obtained, it can be retained for a 
    // short period while you prepare your UI. However, shot previews can become
    // invalid over time, so it's important to check before attempting to fetch the image.
    if (!shotPreview.isValid) {
        return;
    }

    [shotPreview fetchShotPreview:^(NSData* rawImageData, UIImage *image, NSError *error) {
        // This operation is async and can take a few seconds.
        if (error != nil && image != nil) {
            [self showShotPreviewImage:image];
        }
    }];
}];

// Now we've registered, we can take a picture and a preview will be delivered soon after.
[camera invokeOneShotShutterExplicitlyEngagingAutoFocus:YES completionCallback:^(NSError *error) {
    // We don't need to do anything here — if a shot preview becomes available,
    // our registered shot preview observer will be called automatically.
    NSLog(@"Shot taken with error: %@", error);
}];
```

## Properties

You may wish to manipulate various settings of the camera, such as white balance, drive mode, exposure settings, and so on.

Each one of these settings is called a 'property' in CascableCore terms, and each property has:

- A current value.
- A list of valid values that the property can be set to.
- Localized display values (currently only English and German).

A property's current and valid values will all be of the same type. A property's current, valid, and localized values can be `nil` if that setting isn't supported by the connected camera, or if the setting isn't appropriate at the time. For instance, if the camera's exposure mode is set to fully automatic, properties such as `CBLPropertyIdentifierShutterSpeed` and `CBLPropertyIdentifierAperture` may return `nil`.

Since CascableCore supports a huge number of camera models, properties are presented as an opaque list of values, which have display values for presentation to the user. By and large, what these values represent are implementation details of the cameras themselves, and should be presented to the user as-is — the display values should be recognisable to the user.

However, it is of course useful to either know what the camera is doing, or to target a particular camera setting. For this case, we have "common values" — values that are both common to most cameras, and useful to be able to target when getting and setting values. You can't get or set common values directly, but rather you can ask a property value "Do you match this common value?" or "Give me a value to set that matches this common value.".

For example, in example below, we print out the camera's current white balance:

```objc
id <CBLCameraProperty> whiteBalance = [camera propertyWithIdentifier:CBLPropertyIdentifierWhiteBalance];
NSLog(@"The camera's white balance is: %@", whiteBalance.currentValue.localizedDisplayValue);
```

However, since we don't know what particular strings and values the connected camera might report, we can't programatically tell what the white balance actually is. For this, we need to use the common value:

```objc
id <CBLCameraProperty> whiteBalance = [camera propertyWithIdentifier:CBLPropertyIdentifierWhiteBalance];
BOOL isTungsten = (whiteBalance.currentValue.commonValue == CBLPropertyCommonValueWhiteBalanceTungsten);
```

And additionally, we can target a particular, known white balance if the camera is able:

```objc
id <CBLCameraProperty> whiteBalance = [camera propertyWithIdentifier:CBLPropertyIdentifierWhiteBalance];
id <CBLPropertyValue> flashWhiteBalanceValue = [whiteBalance validValueMatchingCommonValue:CBLPropertyCommonValueWhiteBalanceFlash];
if (flashWhiteBalanceValue != nil) {
    [whiteBalance setValue:flashWhiteBalanceValue completionQueue:dispatch_get_main_queue() completionHandler:^(NSError *error) {
        NSLog(@"Set white balance value with error: %@", error);
    }];
}
```

## Filesystem Access

The camera's filesystem is accessed through `CBLCamera`'s `storageDevices` property, which returns an array of `CBLFileStorage` objects.

**Note:** The camera must have the `CBLCameraAvailableCommandCategoryFilesystemAccess` command category active in order to access the filesystem.

It's important to be aware that for performance and memory reasons, the camera's filesystem contents aren't loaded automatically. The directory tree must be navigated and loaded as needed. Once a directory's contents have been loaded with `loadChildren`, that directory's children will automatically be kept up-to-date as files are added and removed.

```objc
id <CBLCamera> camera = …;

id <CBLFileStorage> storage = camera.storageDevices.firstObject;
id <CBLFileSystemFolderItem> rootDirectory = storage.rootDirectory;

if (!rootDirectory.childrenLoaded) {
    [rootDirectory loadChildren:^(NSError *error) {
        NSLog(@"Root directory children: %@", rootDirectory.children);
    }];
}
```

A directory's children can be objects of either type `CBLFileSystemItem` for a regular file or `CBLFileSystemFolderItem` for a child directory.

**Note:** Never assume the directory structure of a camera. While many adhere to the standard `/DCIM/100XXX/` structure, many don't.

When dealing with files (`CBLFileSystemItem`), note that some cameras do not provide file metadata immediately. If this is the case the file's `metadataLoaded` property will be `NO`, and many properties (such as name, etc) will be `nil`. Additionally, in some cases, a file's `size` is not available at all, and will remain `0` at all times.

## Filesystem Change Observation

CascableCore provides API for observing changes to the contents of `CBLFileStorage` objects:

```objc
id <CBLCamera> camera = …;

id <CBLFileStorage> storage = camera.storageDevices.firstObject;
[storage addFileSystemObserver:^(id <CBLFileStorage> storage, 
                                 id <CBLFileSystemFolderItem> modifiedFolder,
                                 CBLFileSystemModificationOperation operation,
                                 NSArray <id <CBLFileSystemItem>> *affectedItems) {
    
    if (operation == CBLFileSystemModificationFilesAdded) {
        NSLog(@"%@ items were added to %@!", @(affectedItems.count), modifiedFolder.name);

    } else if (operation == CBLFileSystemModificationFilesRemoved) {
        NSLog(@"%@ items were removed from %@!", @(affectedItems.count), modifiedFolder.name);
    }
}];
```

**Note:** Change notifications will only be delivered for folders that have had their contents loaded with `loadChildren`. Additionally, change notifications will only be delivered when the camera's command categories contains `CBLCameraAvailableCommandCategoryFilesystemAccess`. However, when switching to this category, notifications will be delivered for changes that have occurred since the last time notifications were delivered.

## Streaming Files

In order to copy a file from the camera, it must be streamed. Streaming is required in order to manage the fact that files can be hundreds of megabytes in size.

If you just need a thumbnail or preview of an image, you don't need to stream the whole file — `fetchThumbnailWithPreflightBlock:thumbnailDeliveryBlock:` and `fetchPreviewWithPreflightBlock:previewDeliveryBlock:` are provided by `CBLFileSystemItem` to fetch smaller versions of images.

A basic example of file streaming can be found below. CascableCore also provides a method that allows streaming to occur entirely on a background thread — see the API documentation for more information. 

```objc
CBLFileStreamPreflight preflightBlock = ^id (id <CBLFileSystemItem> item) {

    // This block is executed once before delivery starts. Use this block to
    // set up local state before file delivery begins. Anything returned
    // from this block will be passed into the delivery and completion blocks.

    NSString *path = [NSString stringWithFormat:@"~/Desktop/%@", item.name];
    path = [path stringByExpandingTildeInPath];

    [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    return [NSFileHandle fileHandleForWritingAtPath:path];
};

CBLFileStreamChunkDelivery deliveryBlock = 
    ^CBLFileStreamInstruction(id <CBLFileSystemItem> item, NSData *chunk, id context) {

    // This block is executed multiple times until the file has been
    // completely delivered. Return CBLFileStreamInstructionCancel to
    // cancel, or CBLFileStreamInstructionContinue to continue.
    NSLog(@"Got data of %@ bytes", @(chunk.length));

    // We created a file handle in the preflight block, which is passed to
    // these delivery blocks in the context parameter. If it's nil, an error
    // happened so we should cancel.
    NSFileHandle *file = context;

    if (file == nil) {
        return CBLFileStreamInstructionCancel;
    }

    // Write the data we received from the camera to disk, cancelling
    // if an exception occurs.
    @try {
        [file writeData:chunk];
    } @catch (NSException *exception) {
        return CBLFileStreamInstructionCancel;
    }

    // Return that we want to continue.
    return CBLFileStreamInstructionContinue;
};

CBLFileStreamCompletion completeBlock = ^(id <CBLFileSystemItem> item, NSError *error, id context) {
    // This block is executed once at the end of the operation, whether the
    // operation was cancelled or not.

    if (error != nil && error.code != CBLErrorCodeCancelledByUser) {
        NSLog(@"An error occurred during copying: %@", error);
    }

    // Close out the file now we've received everything.
    NSFileHandle *file = context;
    [file closeFile];
}

// We've declared all of our streaming blocks — set it going!
id <CBLFileSystemItem> item = …;

[item streamItemWithPreflightBlock:preflightBlock
                chunkDeliveryBlock:deliveryBlock
                     completeBlock:completeBlock];
```
