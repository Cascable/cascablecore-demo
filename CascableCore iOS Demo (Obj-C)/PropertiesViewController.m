//
//  PropertiesViewController.m
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-20.
//  Copyright © 2017 Cascable AB.
//  For license information, see LICENSE.md.

#import "PropertiesViewController.h"
#import "PropertyCell.h"

@interface PropertiesViewController ()
@property (nonatomic, readwrite) id <CBLCamera> camera;
@property (nonatomic, readwrite, copy) NSArray <id <CBLPropertyProxy>> *properties;
@end

@implementation PropertiesViewController

-(void)setupUIForCamera:(id <CBLCamera>)camera {
    self.camera = camera;

    // This example exlusively uses property proxies, which are a helper class for dealing with
    // camera properties.

    NSArray *identifiers = @[@(CBLPropertyIdentifierAperture),
                             @(CBLPropertyIdentifierAutoExposureMode),
                             @(CBLPropertyIdentifierBatteryLevel),
                             @(CBLPropertyIdentifierDriveMode),
                             @(CBLPropertyIdentifierExposureCompensation),
                             @(CBLPropertyIdentifierISOSpeed),
                             @(CBLPropertyIdentifierLightMeterStatus),
                             @(CBLPropertyIdentifierLightMeterReading),
                             @(CBLPropertyIdentifierShotsAvailable),
                             @(CBLPropertyIdentifierShutterSpeed),
                             @(CBLPropertyIdentifierWhiteBalance)];

    NSMutableArray *propertyProxies = [NSMutableArray new];

    for (NSNumber *wrappedIdentifier in identifiers) {
        id <CBLPropertyProxy> proxy = [self.camera proxyForProperty:wrappedIdentifier.unsignedIntegerValue];
        if (proxy != nil) {
            [propertyProxies addObject:proxy];
        }
    }

    self.properties = propertyProxies;
    [self.tableView reloadData];

    // Many cameras (particularly mirrorless ones) don't populate all of their properties until live view is running,
    // since metering systems etc. are directly linked to the sensor being active. So, even though we're not displaying
    // the image, we should enable live view to get the best data.

    // The exception to this, though, is cameras that support remote control without live view.

    // We don't need to do anything once live view is active - CBLPropertyProxy objects will pick up all changes
    // to property values, even if the value was nil before enabling live view. For the UI, our table cells are observing value changes individually.

    if (!self.camera.liveViewStreamActive && ![self.camera supportsFunctionality:CBLCameraRemoteControlWithoutLiveViewFunctionality]) {

        CBLCameraLiveViewFrameDelivery delivery = ^(id<CBLCameraLiveViewFrame> frame, dispatch_block_t completionHandler) {
            // Since we're not actually using the frames here, we don't need to do much. However, we *do* need to call the
            // completion handler, and we can do so with a delay to keep the framerate (and therefore CPU and power use) down.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), completionHandler);
        };

        [self.camera beginLiveViewStreamWithDelivery:delivery
                                       deliveryQueue:dispatch_get_main_queue()
                                  terminationHandler:^(CBLCameraLiveViewTerminationReason reason, NSError * error) {
                                      NSLog(@"Live view terminated.");
                                  }];
    }
}

-(void)viewWillDisappear:(BOOL)animated {
    if (self.camera.liveViewStreamActive) {
        [self.camera endLiveViewStream];
    }
}

#pragma mark - Table view data source

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.properties.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PropertyCell *cell = [tableView dequeueReusableCellWithIdentifier:@"propertyCell" forIndexPath:indexPath];
    cell.property = self.properties[indexPath.row];
    return cell;
}

-(BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

@end
