//
//  LiveViewAndShootingViewController.m
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-19.
//  Copyright © 2017 Cascable AB.
//  For license information, see LICENSE.md.

#import "LiveViewAndShootingViewController.h"
#import "Macros.h"
#import "ShotPreviewViewController.h"

@interface LiveViewAndShootingViewController ()
@property (nonatomic, readwrite) id <CBLCamera> camera;
@property (weak, nonatomic) IBOutlet UIImageView *liveViewImageView;
@property (nonatomic, strong) CBLCameraObserverToken *shotPreviewObserver;
@property (nonatomic, strong) UIImage *lastShotPreviewImage;
@end

@implementation LiveViewAndShootingViewController

-(void)dealloc {
    // Make sure we remove our shot preview observer so it doesn't get fired after we're deallocated!
    if (self.shotPreviewObserver != nil) {
        [self.camera removeShotPreviewObserverWithToken:self.shotPreviewObserver];
    }

    // Turn off live view if it's running.
    if (self.camera.liveViewStreamActive) {
        [self.camera endLiveViewStream];
    }
}

#pragma mark - Live View

-(void)setupUIForCamera:(id <CBLCamera>)camera {

    self.camera = camera;

    // In order to show previews of shots after the shutter has been fired, we need to register a shot preview observer.
    CBLWeakify(self);
    self.shotPreviewObserver = [self.camera addShotPreviewObserver:^(id <CBLCameraShotPreviewDelivery> previewDelivery) {
        CBLStrongify(self);
        [self handleShotPreview:previewDelivery];
    }];

    CBLCameraLiveViewFrameDelivery delivery = ^(id<CBLCameraLiveViewFrame> frame, dispatch_block_t completionHandler) {
        CBLStrongify(self);

        // The live view image frame's image is always in the landscape orientation, even if the camera is rotated.
        // This is because focus areas etc. are always relative to the landscape orientation (i.e., when you rotate
        // the camera, the focus points rotate with it, so they're always relative to the landscape orientation).
        // If the camera supports live view orientation, the frame's orientation property may be something
        // other than CBLCameraLiveViewFrameOrientationLandscape, and you may choose to rotate your UI.
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
}

#pragma mark - Shooting Images

-(IBAction)shootImage:(id)sender {

    // If you need fine-grained control when invoking the focus and shutter, see the engageAutoFocus: et. al. methods.
    // IMPORTANT: The error parameter given in the callback only indicates whether the request was sent without error.
    // Whether or not the shutter was actually fired is a complex decision tree made by the camera, depending on
    // various camera settings and whether or not autofocus was successful etc etc. The result of this decision is not returned.

    [self.camera invokeOneShotShutterExplicitlyEngagingAutoFocus:YES completionCallback:^(NSError *error) {
        if (error != nil) {
            NSLog(@"%@: Shot trigger failed with error: %@", THIS_FILE, error);
        } else {
            NSLog(@"%@: Shot trigger succeeded", THIS_FILE);
        }
    }];
}

#pragma mark - Shot Preview

-(void)handleShotPreview:(id <CBLCameraShotPreviewDelivery>)previewDelivery {

    // Shot previews get delivered (on supported cameras) when a new preview is available. Previews will become invalid
    // after an amount of time, so it's important to check they're still valid before fetching.

    // Since fetching a preview can delay other commands, they're only fetched if you ask for them, which
    // we do here 100% of the time.

    if (!previewDelivery.isValid) {
        NSLog(@"%@: Shot preview received, but it's invalid", THIS_FILE);
        return;
    }

    NSLog(@"%@: Fetching shot preview…", THIS_FILE);

    [previewDelivery fetchShotPreview:^(NSData *sourceData, UIImage *preview, NSError *error) {
        // sourceData is the raw image data as received from the camera, before any rotation etc. is applied.
        // This can be useful if you want to apply your own tranformations to the image.
        if (error != nil || preview == nil) {
            NSLog(@"%@: Shot preview fetch failed with error: %@", THIS_FILE, error);
            return;
        }

        NSLog(@"%@: Shot preview fetch succeeded", THIS_FILE);

        self.lastShotPreviewImage = preview;
        [self performSegueWithIdentifier:@"shotPreview" sender:self];
    }];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue destinationViewController] isKindOfClass:[ShotPreviewViewController class]]) {
        ShotPreviewViewController *previewViewController = (ShotPreviewViewController *)[segue destinationViewController];
        [previewViewController loadViewIfNeeded];
        previewViewController.imageView.image = self.lastShotPreviewImage;
    }
}

@end
