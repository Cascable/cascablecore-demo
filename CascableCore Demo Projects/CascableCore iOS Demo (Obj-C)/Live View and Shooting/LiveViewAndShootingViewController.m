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
@property (nonatomic, strong) CBLCameraObserverToken *cameraInititatedTransferToken;
@property (nonatomic, strong) UIImage *lastShotPreviewImage;
@end

@implementation LiveViewAndShootingViewController

-(void)dealloc {
    // Make sure we remove our camera-initiated transfer handler so it doesn't get fired after we're deallocated!
    if (self.cameraInititatedTransferToken != nil) {
        [self.camera removeCameraInitiatedTransferHandlerWithToken:self.cameraInititatedTransferToken];
    }

    // Turn off live view if it's running.
    if (self.camera.liveViewStreamActive) {
        [self.camera endLiveViewStream];
    }
}

#pragma mark - Live View

-(void)setupUIForCamera:(id <CBLCamera>)camera {

    self.camera = camera;

    // In order to show previews of shots after the shutter has been fired, we need to register a
    // camera-initiated transfer handler.
    CBLWeakify(self);
    self.cameraInititatedTransferToken = [self.camera addCameraInitiatedTransferHandler:^(id <CBLCameraInitiatedTransferRequest> req) {
        CBLStrongify(self);
        [self handleCameraInitiatedTransferRequest:req];
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

#pragma mark - Camera-Initiated Transfers

-(void)handleCameraInitiatedTransferRequest:(id <CBLCameraInitiatedTransferRequest>)request {

    // Camera-initated transfer requests get sent by supported cameras when a new photo has been taken and the
    // camera is presenting on opportunity for that photo to be transferred to a connected host. Transfer requests
    // can become invalid after an amount of time, so it's important to check they're still valid before fetching them.

    // In some situations, this transfer may be the *only* destination of an image — for example, if the camera
    // doesn't have a memory card present or is set to a "host only" image saving mode. If this is the case, the
    // request's `-isOnlyDestinationForImage` property will be set to `YES`. These requests should be executed
    // with the `CBLCameraInitiatedTransferRepresentationOriginal` representation to get the original image file
    // and to avoid data loss. However, for this example we're going to ignore that and only care about previews.

    // Since executing a transfer can delay other commands, they're only executed if you ask for them, which we do
    // here 100% of the time if a preview representation is available.

    if (!request.isValid) {
        NSLog(@"%@: Camera-initated transfer request received, but it's invalid", THIS_FILE);
        return;
    }

    if (![request canProvideRepresentation:CBLCameraInitiatedTransferRepresentationPreview]) {
        NSLog(@"%@: Camera-initated transfer request received, but it can't provide a preview representation", THIS_FILE);
        return;
    }

    NSLog(@"%@: Fetching preview…", THIS_FILE);

    // The `representations` parameter is a bitmask — we can request both the preview and original representations
    // if we want. However, only requesting a preview allows CascableCore to optimise the request and transfer less
    // data from the camera in certain circumstances – reducing the time taken.
    [request executeTransferForRepresentations:CBLCameraInitiatedTransferRepresentationPreview
                             completionHandler:^(id <CBLCameraInitiatedTransferResult> result, NSError *error) {

        if (error != nil || result == nil) {
            NSLog(@"%@: Camera-initiated transfer failed with error: %@", THIS_FILE, error);
            return;
        }

        // At this point, the transfer from the camera is complete and we can use the result object to get at
        // the transferred image representations. In this example, we just want to display a preview image
        // on screen — for more advanced operations, we can write the result out to disk or get it as a raw
        // data object.

        [result generatePreviewImage:^(UIImage *previewImage, NSError *error) {
            // It's rare that we can fail at this point, but it _is_ possible — for example, if the source image
            // is a RAW format we don't know how to handle yet.
            if (previewImage == nil) {
                NSLog(@"%@: Failed to generate preview image with error: %@", THIS_FILE, error);
                return;
            }

            self.lastShotPreviewImage = previewImage;
            [self performSegueWithIdentifier:@"shotPreview" sender:self];
        }];
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
