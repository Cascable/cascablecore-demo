//
//  MainScreenViewController.h
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-19.
//
//

#import <UIKit/UIKit.h>
@import CascableCore;
#import "CameraViewController.h"

@interface MainScreenViewController : UITableViewController <CameraViewController>

@property (nonatomic, readwrite) id <CBLCamera> camera;

@end
