//
//  CameraViewController.h
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-19.
//  Copyright © 2017 Cascable AB.
//  For license information, see LICENSE.md.

@import UIKit;
@import CascableCore;

@protocol CameraViewController <NSObject>

-(void)setupUIForCamera:(id <CBLCamera>)camera;

@property (nonatomic, readonly) id <CBLCamera> camera;

@end
