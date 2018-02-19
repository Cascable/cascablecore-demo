//
//  MainScreenViewController.m
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-19.
//  Copyright © 2017 Cascable AB.
//  For license information, see LICENSE.md.

#import "MainScreenViewController.h"
#import "Macros.h"

typedef NS_ENUM(NSUInteger, DemoScreenRow) {
    DemoScreenRowLiveView = 0,
    DemoScreenRowProperties = 1,
    DemoScreenRowFilesystem = 2
};

@interface MainScreenViewController ()
@property (nonatomic, readwrite) id <CBLCamera> camera;
@property (strong, nonatomic) IBOutlet UIView *busyView;
@end

@implementation MainScreenViewController

#pragma mark - Lifecycle

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupDisconnectionObserver];
    }
    return self;
}

-(void)dealloc {
    [self removeObserver:self forKeyPath:CBLKeyPath(self, camera.connectionState)];
}

-(void)setupUIForCamera:(id <CBLCamera>)camera {
    self.camera = camera;

    if (self.camera != nil) {
        self.title = [NSString stringWithFormat:@"%@ %@", self.camera.deviceInfo.manufacturer, self.camera.deviceInfo.model];
    } else {
        self.title = @"";
    }
}

-(void)viewDidLoad {
    [super viewDidLoad];

    // Since our busy overlay is a floating view in the storyboard, it needs a little setup.
    self.busyView.translatesAutoresizingMaskIntoConstraints = NO;
    self.busyView.layer.cornerRadius = 20.0;
    self.busyView.layer.masksToBounds = YES;

    [self.busyView addConstraint:[NSLayoutConstraint constraintWithItem:self.busyView
                                                              attribute:NSLayoutAttributeWidth
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1.0
                                                               constant:200.0]];

    [self.busyView addConstraint:[NSLayoutConstraint constraintWithItem:self.busyView
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1.0
                                                               constant:200.0]];
}

#pragma mark - Disconnecting

-(void)setupDisconnectionObserver {
    // We add an observer to the camera's connection state so we can react to disconnections. This lets us have a
    // single code path for both disconnections we invoke and unexpected disconnections due to network dropouts etc.
    [self addObserver:self forKeyPath:CBLKeyPath(self, camera.connectionState) options:0 context:nil];
}

- (IBAction)disconnectFromCamera:(id)sender {

    // Disconnect from the camera. We don't _really_ care about the response to this since our connectionState observer deals with disconnections.
    [self.camera disconnect:^(NSError *error) {
        if (error != nil) {
            NSLog(@"%@: Disconnection got error: %@", THIS_FILE, error);
        }
    } callbackQueue:dispatch_get_main_queue()];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {

    // This KVO handler gets called when our camera's connectionState property changes. Here, we react to disconnections.

    if (![keyPath isEqualToString:CBLKeyPath(self, camera.connectionState)]) {
        // (KVO best practices dictate passing observations we don't know about to super)
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    // Here we react to the camera's connection state changing. If the camera is nil or the connection state is anything other than
    // disconnected, we don't need to react.
    if (self.camera == nil || self.camera.connectionState != CBLCameraConnectionStateNotConnected) {
        return;
    }

    // The disconnectionWasExpected property is only valid during a KVO notification triggered by the camera's
    // connectionState or connected properties changing. It's useful for deciding to display an error to the user.
    if (self.camera.disconnectionWasExpected) {
        self.camera = nil;
        [self performSegueWithIdentifier:@"unwindToDiscovery" sender:nil];
        NSLog(@"%@: Expected disconnection encountered - unwinding to camera discovery.", THIS_FILE);

    } else {
        // In this case, the disconnection was not expected — it may have been caused by a network dropout, etc. Display a warning to the user.
        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Camera Disconnected!"
                                            message:@"The camera disconnected unexpectedly. This may have been caused "
                                                    @"by moving too far away from the camera, or by turning it off."
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
            [alert dismissViewControllerAnimated:YES completion:nil];
            [self performSegueWithIdentifier:@"unwindToDiscovery" sender:nil];
        }]];

        self.camera = nil;
        [self presentViewController:alert animated:YES completion:nil];
        NSLog(@"%@: Unexpected disconnection encountered! Alerting before unwinding to camera discovery.", THIS_FILE);
    }
}

#pragma mark - Camera Mode Switching

-(void)ensureCameraAllows:(CBLCameraAvailableCommandCategory)category thenPerformSegue:(NSString *)segueIdentifier {

    // Cameras often don't allow all functionality at once. A common division of functionality is remote shooting and access to the
    // camera's filesystem — you can do either, but not both.

    // However, some cameras *do* allow both, so the currentCommandCategories property is actually a bitmask. To aid working with this,
    // there's APIs to query whether the camera currently allows a given command category:

    // [self.camera currentCommandCategoriesContainsCategory:CBLCameraAvailableCommandCategoryRemoteShooting]

    // However, it's a harmless operation to set the command category to one that's already allowed. Therefore, to reduce
    // code paths, in this example we just set the required command category without checking if it's already available first.

    NSString *categoryName = category == CBLCameraAvailableCommandCategoryRemoteShooting ? @"remote shooting" : @"filesystem access";
    NSLog(@"%@: Switching camera category to %@…", THIS_FILE, categoryName);

    self.view.userInteractionEnabled = NO;
    [self showBusyOverlay];

    CBLWeakify(self);
    [self.camera setCurrentCommandCategories:category completionCallback:^(NSError *error) {
        CBLStrongify(self);
        NSLog(@"%@: …category switch complete.", THIS_FILE);
        [self performSegueWithIdentifier:segueIdentifier sender:self];
        self.view.userInteractionEnabled = YES;
        [self hideBusyOverlay];
    }];
}

-(void)showBusyOverlay {
    [self.busyView removeFromSuperview];
    [self.view addSubview:self.busyView];

    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.busyView
                                                          attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeCenterX
                                                         multiplier:1.0 constant:0.0]];

    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.busyView
                                                          attribute:NSLayoutAttributeCenterY
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeCenterY
                                                         multiplier:1.0 constant:0.0]];
}

-(void)hideBusyOverlay {
    [self.busyView removeFromSuperview];
}

#pragma mark - Table view data source

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == DemoScreenRowLiveView) {
        [self ensureCameraAllows:CBLCameraAvailableCommandCategoryRemoteShooting thenPerformSegue:@"liveViewShooting"];

    } else if (indexPath.row == DemoScreenRowProperties) {
        [self ensureCameraAllows:CBLCameraAvailableCommandCategoryRemoteShooting thenPerformSegue:@"properties"];

    } else if (indexPath.row == DemoScreenRowFilesystem) {
        [self ensureCameraAllows:CBLCameraAvailableCommandCategoryFilesystemAccess thenPerformSegue:@"filesystem"];
    }
}

#pragma mark - Navigation

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Hand off our connected camera to the next view controller.

    if ([segue.destinationViewController conformsToProtocol:@protocol(CameraViewController)]) {
        id <CameraViewController> cameraViewController = segue.destinationViewController;
        [cameraViewController setupUIForCamera:self.camera];
    }
}

@end
