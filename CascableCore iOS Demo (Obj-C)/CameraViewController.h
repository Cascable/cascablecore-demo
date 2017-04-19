//
//  CameraViewController.h
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-19.
//
//

@import UIKit;
@import CascableCore;

@protocol CameraViewController <NSObject>

-(void)setupUIForCamera:(id <CBLCamera>)camera;

@property (nonatomic, readonly) id <CBLCamera> camera;

@end
