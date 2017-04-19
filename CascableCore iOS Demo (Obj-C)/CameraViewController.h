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

@property (nonatomic, readwrite) id <CBLCamera> camera;

@end
