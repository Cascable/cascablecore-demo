# Getting Started With CascableCore

CascableCore is a framework for connecting to and working with Wi-Fi enabled cameras from Canon, Fujifilm, Nikon, Olympus, Panasonic, and Sony.

This document is a technical quick-start guide, giving an overview of the framework's overall use and some tips and tricks for getting started efficiently.

Code samples are in Objective-C, but CascableCore is fully compatible with Swift 3. For more information on specific APIs, see CascableCore's API documentation.

## Adding CascableCore To Your Project

First, move `CascableCore.framework` to a sensible location in your project's structure, then drag it into your Xcode project.

Next, navigate to your target's **General** settings and ensure `CascableCore.framework` is listed in both the **Embedded Binaries** and **Linked Frameworks and Libraries** section.

<img src="Documentation%20Images/setup-general.png" width="959">

Next, **only if your project only contains Objective-C**, navigate to **Build Settings** and ensure that **Always Embed Swift Standard Libraries** is set to **Yes**. If your project contains Swift code or depends on Swift libraries, there's no need to perform this step.

Finally, navigate to **Build Phases** and add a new **Copy Files** build phase, with the destination set to **Frameworks**. Ensure that CascableCore is listed in this phase. 

<img src="Documentation%20Images/setup-copyframeworks.png" width="1022">

## App Transport Security

If your app is limited by App Transport Security, you need to allow CascableCore to talk to the cameras on your local network.

On iOS 10 and macOS 10.12 and above, set `NSAllowsLocalNetworking` to `YES` in your App Transport Security settings.

<img src="Documentation%20Images/ats.png" width="562">

On iOS 9 and macOS 10.11 or lower, you need to disable App Transport Security entirely, by setting `NSAllowsArbitraryLoads` to `YES`. If you do this, you may need to describe why to Apple in order to pass App Review. A paragraph similar to this may suffice:

> App Transport Security has been disabled for this app on iOS 9 and lower. This is because the app needs to communicate with cameras discovered on the local network, and App Transport Security  provides no way to whitelist the local network or IP address ranges on iOS 9 or lower.

If you support iOS 10/macOS 10.12 and lower you can set both `NSAllowsLocalNetworking` to `YES` _and_ `NSAllowsArbitraryLoads` to `YES` to disable App Transport Security on older OS versions, but use the more secure local networking exemption on newer OS versions. For more information on this, see [this thread on the Apple Developer Forums](https://forums.developer.apple.com/thread/6767).

CascableCore makes no attempt to communicate with the outside world via the Internet, so no domain-specific App Transport Security exemptions are needed.

## App Store Preparation (iOS Only)

The `CascableCore.framework` iOS binary contains both simulator and device architectures, allowing you to work both in the iOS Simulator and on iOS devices. Unfortunately, iTunes Connect will refuse to accept binaries that contain simulator architectures. If you already have a solution for this problem for other dependencies, that solution should work with CascableCore as well. Otherwise, this build phase script will look through all of your built application's embedded frameworks and strip out architectures not being used for that build. 

To use it, create a new **Run Script** build phase at the **end** of your existing build phases, set the shell to `/bin/sh` and enter the following script:

```sh
if [ "${CONFIGURATION}" = "Debug" ]; then
    echo "Debug build, skipping framework architecture stripping"
    exit 0
fi

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"

# This script loops through the frameworks embedded in the application and
# removes unused architectures.
find "$APP_PATH" -name '*.framework' -type d | while read -r FRAMEWORK
do
    FRAMEWORK_EXECUTABLE_NAME=$(defaults read "$FRAMEWORK/Info.plist" CFBundleExecutable)
    FRAMEWORK_EXECUTABLE_PATH="$FRAMEWORK/$FRAMEWORK_EXECUTABLE_NAME"
    echo "Executable is $FRAMEWORK_EXECUTABLE_PATH"

    EXTRACTED_ARCHS=()

    for ARCH in $ARCHS
    do
        echo "Extracting $ARCH from $FRAMEWORK_EXECUTABLE_NAME"
        lipo -extract "$ARCH" "$FRAMEWORK_EXECUTABLE_PATH" -o "$FRAMEWORK_EXECUTABLE_PATH-$ARCH"
        EXTRACTED_ARCHS+=("$FRAMEWORK_EXECUTABLE_PATH-$ARCH")
    done

    echo "Merging extracted architectures: ${ARCHS}"
    lipo -o "$FRAMEWORK_EXECUTABLE_PATH-merged" -create "${EXTRACTED_ARCHS[@]}"
    rm "${EXTRACTED_ARCHS[@]}"

    echo "Replacing original executable with thinned version"
    rm "$FRAMEWORK_EXECUTABLE_PATH"
    mv "$FRAMEWORK_EXECUTABLE_PATH-merged" "$FRAMEWORK_EXECUTABLE_PATH"

done
```

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

<img src="Documentation%20Images/arguments.png" width="930">

Again, these parameters are only needed when working in the iOS Simulator.

## Connecting To and Disconnecting From Cameras

Once you've discovered a camera, you'll probably want to connect to it! 

It's important to be aware that sometimes, cameras will halt the incoming connection process to ask the user something. This typically happens if the camera's connection workflow requires 'pairing' with apps.

When this occurs, CascableCore invokes what's called a "user intervention callback". When this is called, it's important to display UI in your app telling the user that they need to look at their camera and follow any on-screen instructions. Once the camera continues with the connection, CascableCore will call the user intervention callback again letting you know that it's safe to hide the UI. 

In our own apps, we display a dialog like this:

<img src="Documentation%20Images/user-intervention-dialog-example.png" width="301">

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

To enable live view, use `CBLCamera`'s `setLiveViewEnabled:callback:` method. You can be notified of new live view frames by Key-Value observing your camera's `liveViewFrame` property.

It's important to bear in mind that a camera's focus points will be relative to a given coordinate system which will certainly be different to your application's views, and often different to the size of the image given by the camera. In some cases, the aspect ratio may not even match — some Panasonic cameras place AF areas in a square of `1000x1000` even if the viewfinder image is at an aspect ratio of `4:3` or even `16:9`.

To assist with this, `CBLCameraLiveViewFrame` objects returned by a camera's `liveViewFrame` property contain a numer of geometry transformation methods that perform the relevant math for you. Otherwise, you can get the camera's coordinate space using `CBLCameraLiveViewFrame`'s `aspect` property.

```objc
// In this example, we want to render the camera's AF areas on top of the
// image view showing the live view image. However, the AF areas must be
// translated from the camera's coordinate system to the image view's
// coordinate system.

// The image view must be sized so the live view image fills it 
// completely for this logic to work correctly.
UIImageView *imageView = …;
id <CBLCamera> camera = …;
id <CBLCameraLiveViewFrame> liveViewFrame = camera.liveViewFrame;

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
    id <CBLCameraLiveViewFrame> liveViewFrame = camera.liveViewFrame;

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

A property's current and valid values will all be of the same type. For 'simple' enum types such as white balance, drive modes, etc, the values will be `NSNumber` objects containing a value of the relevant `enum` type. For exposure property values, the values will be of the respective exposure type — `CBLISOValue`, `CBLShutterSpeedValue`, etc.

A property's value and valid values can change at any time. CascableCore provides API for all of this, but the preferred way of interacting with camera properties is to use a *property proxy*, which is a helper object that represents the current and valid values of a camera property, as well as providing localisation helpers and value setters.

A property's current, valid and localized values can be `nil` if that setting isn't supported by the connected camera, or if the setting isn't appropriate at the time. For instance, if the camera's exposure mode is set to fully automatic, properties such as `CBLPropertyIdentifierShutterSpeed` and `CBLPropertyIdentifierAperture` may return `nil`.

```objc
id <CBLCamera> camera = …;

id <CBLPropertyProxy> whiteBalance = [camera proxyForProperty:CBLPropertyIdentifierWhiteBalance];

// Example values: CBLWhiteBalanceAutomatic, CBLWhiteBalanceSunny, etc. 
CBLWhiteBalance wbValue = [whiteBalance.value intValue];

// Example values: "Automatic", "Sunny", etc.
NSString *stringValue = whiteBalance.localizedDisplayValue;

// When setting a value, the type must match (for white balance, an NSNumber
// containing a CBLWhiteBalance value) and the value must be contained in the
// validSettableValues array.
[whiteBalance setValue:@(CBLWhiteBalanceSunny) callback:^(NSError *error) {
    NSLog(@"Property set complete with error %@", error);
}];
```

```objc
id <CBLCamera> camera = …;

id <CBLPropertyProxy> iso = [camera proxyForProperty:CBLPropertyIdentifierISOSpeed];

// Example values: [CBLISOValue ISO200], [CBLISOValue automaticISO], etc. 
CBLISOValue *isoValue = iso.value;

// Example values: "ISO 200", "Automatic", etc.
NSString *stringValue = iso.localizedDisplayValue;

// When setting a value, the type must match (for ISO, a CBLISOValue
// object) and the value must be contained in the validSettableValues array.
[iso setValue:[CBLISOValue ISO200] callback:^(NSError *error) {
    NSLog(@"Property set complete with error %@", error);
}];
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
