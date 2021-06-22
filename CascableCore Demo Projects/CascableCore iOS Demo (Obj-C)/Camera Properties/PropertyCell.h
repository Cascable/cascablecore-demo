//
//  PropertyCell.h
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-20.
//  Copyright © 2017 Cascable AB.
//  For license information, see LICENSE.md.

#import <UIKit/UIKit.h>
@import CascableCore;

@interface PropertyCell : UITableViewCell

@property (nonatomic, readwrite) id <CBLCameraProperty> property;

@end
