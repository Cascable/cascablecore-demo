//
//  CameraDiscoveryViewController.m
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-19.
//  Copyright © 2017 Cascable AB.
//  For license information, see LICENSE.md.

#import "CameraDiscoveryViewController.h"
@import CascableCore;
#import "Macros.h"
#import "CameraViewController.h"

@interface CameraDiscoveryViewController () <CBLCameraDiscoveryDelegate>
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (nonatomic, nullable) UIAlertController *pairingAlert;
@property (nonatomic, nullable) id <CBLCamera> lastConnectedCamera;
@end

@implementation CameraDiscoveryViewController

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self resetDiscovery];
}

#pragma mark - Camera Discovery

-(void)discovery:(CBLCameraDiscovery *)discovery didDiscoverCamera:(id <CBLCamera>)camera {

    // We're using the camera's service here to log a bit of info about the camera.
    // A camera's deviceInfo property is often not populated until the camera is connected.
    id <CBLCameraDiscoveryService> service = camera.service;
    NSLog(@"%@: Found a %@ %@ at %@!", THIS_FILE, service.manufacturer, service.model, service.ipv4Address);

    // We only want one camera, so stop searching as soon as we've found one.
    NSLog(@"%@: Stopping camera discovery", THIS_FILE);
    [discovery stopSearching];

    [self connectToCamera:camera];
}

-(void)discovery:(CBLCameraDiscovery *)discovery didLoseSightOfCamera:(id <CBLCamera>)camera {
    // In this demo, we don't care if a camera disappears since we're not maintaining a list of available cameras.
    // Cameras can disappear from discovery after being connected to, which is normal behaviour.
}

#pragma mark - Connection

-(void)connectToCamera:(id <CBLCamera>)camera {

    self.titleLabel.text = @"Connecting…";
    NSLog(@"%@: Connecting to %@…", THIS_FILE, camera.service.model);

    [camera connectWithCompletionCallback:^(NSError * _Nullable error, NSArray<id<CBLCameraConnectionWarning>> * _Nullable warnings) {

        if (error != nil) {
            if (error.code != CBLErrorCodeCancelledByUser) {
                // If the user cancelled, don't display an error.
                [self displayConnectionError:error];
            }

            [self resetDiscovery];
        } else {
            [self transitionToMainDemoScreenWithCamera:camera];
        }

    } userInterventionCallback:^(BOOL shouldDisplayUserInterventionDialog, dispatch_block_t _Nullable cancelConnectionBlock) {
        // This block will be called if connection is halted due to the user needing to perform one or more
        // actions on the camera itself. When this happens, you should display UI to the user telling them
        // to look at the camera.

        // This will be called either zero or two times. Zero if no user intervention is required, twice if it is — once when
        // it's appropriate to show UI to tell the user to look at the camera (the shouldDisplayUserInterventionDialog
        // parameter will be `YES`), and once when that UI can be dismissed (the shouldDisplayUserInterventionDialog
        // parameter will be `NO`).

        // The cancelConnectionBlock parameter will be non-nil when shouldDisplayUserInterventionDialog is `YES`,
        // and can be called to cancel the connection and abort the pairing.

        if (shouldDisplayUserInterventionDialog) {
            [self displayPairingRequiredUI:cancelConnectionBlock];
        } else {
            [self dismissPairingRequiredUI];
        }
    }];

}

-(void)displayPairingRequiredUI:(dispatch_block_t)cancelConnection {

    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:@"Pairing Required!"
                                        message:@"Please follow the instructions on your camera's screen to continue."
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel Connection" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        cancelConnection();
        [self dismissPairingRequiredUI];
    }]];

    self.pairingAlert = alert;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)dismissPairingRequiredUI {

    if (self.pairingAlert == nil) {
        return;
    }

    [self.pairingAlert dismissViewControllerAnimated:YES completion:^{
        self.pairingAlert = nil;
    }];
}

#pragma mark - Connection UI

-(void)resetDiscovery {
    self.titleLabel.text = @"Searching for cameras…";
    NSLog(@"%@: Starting camera discovery", THIS_FILE);

    // Set up discovery using delegate methods. You can also use KVO or block callbacks.
    CBLCameraDiscovery *discovery = [CBLCameraDiscovery sharedInstance];

    // The client name will be shown on the screen of some cameras when pairing.
    // It must be set before you start searching for cameras.
    discovery.clientName = @"CascableCore Demo";
    discovery.delegate = self;
    [discovery beginSearching];
}

-(void)displayConnectionError:(nonnull NSError *)error {

    NSString *errorDescription = error.localizedDescription;
    if (errorDescription == nil) {
        errorDescription = [NSString stringWithFormat:@"%@", error];
    }

    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:@"Connection Error!"
                                        message:errorDescription
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [alert dismissViewControllerAnimated:YES completion:nil];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

-(void)transitionToMainDemoScreenWithCamera:(id <CBLCamera>)camera {
    NSLog(@"%@: Connection to %@ successful - transitioning to main screen", THIS_FILE, camera.service.model);
    self.lastConnectedCamera = camera;
    [self performSegueWithIdentifier:@"mainDemoScreen" sender:nil];
}

#pragma mark - Navigation

-(IBAction)unwindToDiscovery:(UIStoryboardSegue *)unwindSegue {
    // This is a no-op method to support storyboard segue unwinding to this view controller.
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Hand off our connected camera to the next view controller.

    if ([segue.destinationViewController conformsToProtocol:@protocol(CameraViewController)]) {
        id <CameraViewController> cameraViewController = segue.destinationViewController;
        [cameraViewController setupUIForCamera:self.lastConnectedCamera];
    }
}

@end
