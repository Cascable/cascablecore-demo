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
@property (nonatomic, nullable) UIAlertController *authenticationAlert;
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

    [camera connectWithAuthenticationRequestCallback:^(id <CBLCameraAuthenticationContext> _Nonnull context) {
        // This block will be called if connection is halted due to the camera requiring authentication of some kind.

        // This and the `authenticationResolvedCallback` callback will always be called in pairs. Authentication UI
        // should be shown to the user in this callback, then hidden (if still visible) in `authenticationResolvedCallback`.
        // Which action should be taken by the user is defined in the `context` object. See `-displayAuthenticationUI:`
        // below for examples.
        [self displayAuthenticationUI:context];

    } authenticationResolvedCallback:^{
        // This block will be called after authentication has been "resolved" - hide any displayed authentication UI.
        [self dismissAuthenticationUI];

    } completionCallback:^(NSError * _Nullable error, NSArray <id <CBLCameraConnectionWarning>> * _Nullable warnings) {
        // This is the completion block, which will be called after the connection has successfully
        // completed or has failed.
        if (error != nil) {
            if (error.code != CBLErrorCodeCancelledByUser) {
                // If the user cancelled, don't display an error.
                [self displayConnectionError:error];
            }

            [self resetDiscovery];
        } else {
            [self transitionToMainDemoScreenWithCamera:camera];
        }
    }];

}

-(void)displayAuthenticationUI:(id <CBLCameraAuthenticationContext> _Nonnull)authenticationContext {

    // What we display to the user depends on which kind of authentication the camera wants. Currently,
    // there are three kinds:
    //
    // - "Interact with camera" means that the only thing you can do is cancel the connection. The user must
    //   physically interact with the camera to approve the connection.
    //
    // - "Username and password" means that a username and password should be collected and submitted.
    //
    // - "Four digit code" means that a four digic numeric code should be collected and submitted.

    switch (authenticationContext.type) {
        case CBLCameraAuthenticationTypeInteractWithCamera:
            [self presentInteractWithCameraAuthenticationUI:authenticationContext];
            break;

        case CBLCameraAuthenticationTypeUsernameAndPassword:
            [self presentUsernameAndPasswordAuthenticationUI:authenticationContext];
            break;

        case CBLCameraAuthenticationTypeFourDigitNumericCode:
            [self presentFourDigitNumericCodeAuthenticationUI:authenticationContext];
            break;
    }
}

-(void)presentInteractWithCameraAuthenticationUI:(id <CBLCameraAuthenticationContext> _Nonnull)authenticationContext {
    // Here, we display an authentication alert instructing the user to interact with the camera to continue.
    // When the user does so, the `authenticationResolvedCallback` given to the camera's connection invocation
    // will be called.
    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:@"Pairing Required!"
                                        message:@"Please follow the instructions on your camera's screen to continue."
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Disconnect" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        // We dismiss the alert right away here, but we don't have to — we could instead disable the buttons etc
        // and wait for the `authenticationResolvedCallback` to be called above.
        [self dismissAuthenticationUI];
        [authenticationContext submitCancellation];
    }]];

    self.authenticationAlert = alert;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)presentUsernameAndPasswordAuthenticationUI:(id <CBLCameraAuthenticationContext> _Nonnull)authenticationContext {
    // Here, we display an authentication alert asking for a username and password, which we then submit to the camera
    // via the given authentication context. When the user does so, the `authenticationResolvedCallback` given to the
    // camera's connection invocation will be called.

    // Some cameras let us try again if incorrect details were submitted.
    BOOL previousAttemptFailed = authenticationContext.previousSubmissionRejected;

    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:previousAttemptFailed ? @"Incorrect Username/Password" : @"Authentication Required"
                                        message:@"Please enter your camera's username and password."
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Username";
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Password";
        textField.secureTextEntry = YES;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Disconnect" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        // We dismiss the alert right away here, but we don't have to — we could instead disable the buttons etc
        // and wait for the `authenticationResolvedCallback` to be called above.
        [self dismissAuthenticationUI];
        [authenticationContext submitCancellation];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Submit" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        // We dismiss the alert right away here, but we don't have to — we could instead disable the buttons etc
        // and wait for the `authenticationResolvedCallback` to be called above.
        NSString *userName = alert.textFields.firstObject.text;
        if (userName == nil) { userName = @""; }
        NSString *password = [alert.textFields objectAtIndex:1].text;
        if (password == nil) { password = @""; }
        [self dismissAuthenticationUI];
        [authenticationContext submitUserName:userName password:password];
    }]];

    self.authenticationAlert = alert;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)presentFourDigitNumericCodeAuthenticationUI:(id <CBLCameraAuthenticationContext> _Nonnull)authenticationContext {
    // Here, we display an authentication alert asking for a four-digit code, which we then submit to the camera
    // via the given authentication context. When the user does so, the `authenticationResolvedCallback` given to the
    // camera's connection invocation will be called.

    // Some cameras let us try again if incorrect details were submitted.
    BOOL previousAttemptFailed = authenticationContext.previousSubmissionRejected;

    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:previousAttemptFailed ? @"Incorrect Passcode" : @"Authentication Required"
                                        message:@"Please enter your camera's passcode."
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Passcode";
        textField.secureTextEntry = YES;
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Disconnect" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        // We dismiss the alert right away here, but we don't have to — we could instead disable the buttons etc
        // and wait for the `authenticationResolvedCallback` to be called above.
        [self dismissAuthenticationUI];
        [authenticationContext submitCancellation];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Submit" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        // We dismiss the alert right away here, but we don't have to — we could instead disable the buttons etc
        // and wait for the `authenticationResolvedCallback` to be called above.
        NSString *code = alert.textFields.firstObject.text;
        if (code == nil) { code = @""; }
        [self dismissAuthenticationUI];
        [authenticationContext submitNumericCode:code];
    }]];

    self.authenticationAlert = alert;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)dismissAuthenticationUI {
    // This can be called either from our own UI methods or from the `authenticationResolvedCallback` during connection.
    if (self.authenticationAlert == nil) { return; }
    [self.authenticationAlert dismissViewControllerAnimated:YES completion:^{}];
    self.authenticationAlert = nil;
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
