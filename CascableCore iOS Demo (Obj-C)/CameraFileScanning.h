//
//  CameraFileScanning.h
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-20.
//  Copyright © 2017 Cascable AB.
//  For license information, see LICENSE.md.

#import <Foundation/Foundation.h>
@import CascableCore;

typedef BOOL (^CameraFileScanningPredicate)(id <CBLFileSystemItem> _Nonnull);
typedef void (^CameraFileScanningCompletion)(NSArray <id <CBLFileSystemItem>> * _Nullable , NSError * _Nullable);

typedef NS_ENUM(NSUInteger, CameraFileScanningErrorCode) {
    CameraFileScanningErrorCodeNoStorageDevices = 2001,
    CameraFileScanningErrorCodeNoRootFolders = 2002
};

/**
 The CameraFileScanning class provides helpers for navigating a camera's filesystem hierarchy and extracting files you're interested in.
 */
@interface CameraFileScanning : NSObject

/// Returns the shared camera scanning object,
+(instancetype _Nonnull)sharedInstance;

/**
 Iterate the camera's filesystem for items. This operation may take a long time.

 @param camera The camera to iterate.
 @param predicate The predicate to filter out files. In the filter block, return `YES` if you want the passed item, 
        otherwise `NO`. Pass `nil` to this parameter to return all files.
 @param completion The completion block to be triggered once iteration has completed or fails.
 */
-(void)scanForFilesInCamera:(nonnull id <CBLCamera>)camera
          matchingPredicate:(nullable CameraFileScanningPredicate)predicate
                   callback:(nonnull CameraFileScanningCompletion)completion;

@end
