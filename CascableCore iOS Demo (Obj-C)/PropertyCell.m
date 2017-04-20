//
//  PropertyCell.m
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-20.
//
//

#import "PropertyCell.h"
#import "Macros.h"

static void * const PropertyCellKVOContext = @"PropertyCellKVOContext";

@implementation PropertyCell

#pragma mark - Lifecycle

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self addObservers];
    }
    return self;
}

-(id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self addObservers];
    }
    return self;
}

-(id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self addObservers];
    }
    return self;
}

-(void)addObservers {
    [self addObserver:self forKeyPath:CBLKeyPath(self, property.value) options:0 context:PropertyCellKVOContext];
    [self addObserver:self forKeyPath:CBLKeyPath(self, property.propertyName) options:0 context:PropertyCellKVOContext];
}

-(void)awakeFromNib {
    [super awakeFromNib];
    self.detailTextLabel.textColor = [UIColor grayColor];
    [self updateLabels];
}

-(void)dealloc {
    [self removeObserver:self forKeyPath:CBLKeyPath(self, property.value)];
    [self removeObserver:self forKeyPath:CBLKeyPath(self, property.propertyName)];
}

#pragma mark - Reacting to Changes

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {

    if (context != PropertyCellKVOContext) {
        // (KVO best practices dictate passing observations we don't know about to super)
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    [self updateLabels];
}

-(void)updateLabels {

    // Localized properties can always return nil - especially if your app is localised in a language that
    // CascableCore isn't. If that's important, you can fall back to the propertyName property.
    NSString *displayName = self.property.localizedPropertyName;
    if (displayName == nil) {
        displayName = self.property.propertyName;
    }

    // When figuring out a display value, the localizedDisplayValue property of a proxy is the best place
    // to start. However, this can always return nil, so it's important to have a fallback.

    // It's worth noting that property values can and will return nil instead of a value in many circumstances.
    // For instance, when a camera is in the manual exposure mode, exposure compensation may be nil.
    NSString *displayValue = self.property.localizedDisplayValue;

    if (displayValue.length == 0) {
        id value = self.property.value;

        if (value == nil) {
            // A nil value is normal and expected in many cases.
            displayValue = @"No Value";

        } else if ([value conformsToProtocol:@protocol(CBLUniversalExposurePropertyValue)]) {
            // Exposure values (ISO, shutter speed, etc) have a succinctDescription property, which is handy for this.
            id <CBLUniversalExposurePropertyValue> exposureProperty = value;
            displayValue = exposureProperty.succinctDescription;

        } else if ([value isKindOfClass:[NSNumber class]] && [value integerValue] == NSNotFound) {
            // For properties that return a numeric value, the 'unknown' value will always be NSNotFound.
            displayValue = @"Unknown";

        } else {
            // For this demo, we'll fall back to shoving the value into a string. This isn't a good idea for production apps.
            displayValue = [NSString stringWithFormat:@"%@", self.property.value];
        }
    }

    self.textLabel.text = displayName;
    self.detailTextLabel.text = displayValue;
}

@end
