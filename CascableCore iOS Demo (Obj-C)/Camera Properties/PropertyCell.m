//
//  PropertyCell.m
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-20.
//  Copyright © 2017 Cascable AB.
//  For license information, see LICENSE.md.

#import "PropertyCell.h"
#import "Macros.h"

@interface PropertyCell ()
@property (nonatomic, readwrite, strong) id <CBLCameraPropertyObservation> changeObservation;
@end

@implementation PropertyCell

#pragma mark - Lifecycle

-(void)awakeFromNib {
    [super awakeFromNib];
    self.detailTextLabel.textColor = [UIColor grayColor];
    [self updateLabels];
}

-(void)dealloc {
    [self removeObservers];
}

#pragma mark - Reacting to Changes

-(void)setProperty:(id<CBLCameraProperty>)property {
    [self removeObservers];
    _property = property;
    [self addObservers];
}

-(void)addObservers {
    if (self.property == nil) { return; }

    // We'll observe the value and name properties for changes. That way, we can update our labels as appropriate.

    CBLWeakify(self);
    self.changeObservation = [self.property addObserver:^(id <CBLCameraProperty> sender, CBLPropertyChangeType type) {
        CBLStrongify(self);
        // We can use the sender and type parameters to react to the changes in a more controlled manner. For the
        // demo, though, we'll just update our labels no matter what.
        [self updateLabels];
    }];
}

-(void)removeObservers {
    [self.changeObservation invalidate];
    self.changeObservation = nil;
}

-(void)updateLabels {

    // Localized properties can always return nil - especially if your app is localised in a language that
    // CascableCore isn't.
    NSString *displayName = self.property.localizedDisplayName;
    if (displayName == nil) {
        displayName = @"Unknown Property";
    }

    // When figuring out a display value, the localizedDisplayValue property of a property's value is the best place
    // to start. However, this can always return nil, so it's important to have a fallback.

    // It's worth noting that property values can and will return nil instead of a value in many circumstances.
    // For instance, when a camera is in the manual exposure mode, exposure compensation may be nil.
    NSString *displayValue = self.property.currentValue.localizedDisplayValue;

    if (displayValue.length == 0) {
        id <CBLPropertyValue> value = self.property.currentValue;

        if (value == nil) {
            // A nil value is normal and expected in many cases.
            displayValue = @"No Value";

        } else if ([value conformsToProtocol:@protocol(CBLExposurePropertyValue)]) {
            // Exposure values (ISO, shutter speed, etc) have a succinctDescription property, which is handy for this demo.
            id <CBLExposurePropertyValue> currentExposureValue = (id <CBLExposurePropertyValue>)value;
            displayValue = currentExposureValue.exposureValue.succinctDescription;

        } else if (value.commonValue == CBLPropertyCommonValueNone) {
            // For properties that return a numeric value, the 'unknown' value will always be CBLPropertyCommonValueNone.
            displayValue = @"Unknown";

        } else {
            // For this demo, we'll fall back to shoving the value's internal value into a string.
            // This isn't a good idea for production apps.
            displayValue = [NSString stringWithFormat:@"%@", value.opaqueValue];
        }
    }

    self.textLabel.text = displayName;
    self.detailTextLabel.text = displayValue;
}

@end
