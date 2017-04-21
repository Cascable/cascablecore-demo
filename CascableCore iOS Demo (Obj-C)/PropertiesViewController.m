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

    if (!self.camera.liveViewEnabled && ![self.camera supportsFunctionality:CBLCameraRemoteControlWithoutLiveViewFunctionality]) {

        // Some cameras allow for a reduced Live View refresh rate, which can be handy for reducing power consumption
        // in both the camera and the iOS device.
        self.camera.liveViewUpdateFrequency = CBLCameraLiveViewUpdateFrequencyReduced;

        [self.camera setLiveViewEnabled:YES callback:^(NSError *error) {
            // We don't need to do anything here – CBLPropertyProxy objects will pick up and changes
            // to property values, even if the value was nil before enabling live view. For the UI, our table cells
            // are observing value changes individually.
        }];
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
