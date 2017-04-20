//
//  PropertyCell.h
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-20.
//
//

#import <UIKit/UIKit.h>
@import CascableCore;

@interface PropertyCell : UITableViewCell

@property (nonatomic, readwrite) id <CBLPropertyProxy> property;

@end
