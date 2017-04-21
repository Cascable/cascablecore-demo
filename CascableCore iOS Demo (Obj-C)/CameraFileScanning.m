//
//  CameraFileScanning.m
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-20.
//  Copyright © 2017 Cascable AB.
//  For license information, see LICENSE.md.

#import "CameraFileScanning.h"

@implementation CameraFileScanning

+(instancetype _Nonnull)sharedInstance {
    static CameraFileScanning *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [CameraFileScanning new];
    });
    return sharedInstance;
}

-(void)scanForFilesInCamera:(nonnull id <CBLCamera>)camera
          matchingPredicate:(nullable CameraFileScanningPredicate)predicate
                   callback:(nonnull CameraFileScanningCompletion)completion {

    if (![camera currentCommandCategoriesContainsCategory:CBLCameraAvailableCommandCategoryFilesystemAccess]) {
        // Can't scan without filesystem access!
        NSError *error = [NSError errorWithDomain:CBLErrorDomain code:CBLErrorCodeIncorrectCommandCategory userInfo:nil];
        completion(nil, error);
        return;
    }

    NSArray <id <CBLFileStorage>> *storageDevices = camera.storageDevices;

    if (storageDevices.count == 0) {
        NSError *error = [NSError errorWithDomain:CBLErrorDomain code:CameraFileScanningErrorCodeNoStorageDevices userInfo:nil];
        completion(nil, error);
        return;
    }

    NSMutableArray *rootFolders = [NSMutableArray new];

    for (id <CBLFileStorage> storage in storageDevices) {
        id <CBLFileSystemFolderItem> root = storage.rootDirectory;
        if (root != nil) {
            [rootFolders addObject:root];
        }
    }

    if (rootFolders.count == 0) {
        NSError *error = [NSError errorWithDomain:CBLErrorDomain code:CameraFileScanningErrorCodeNoRootFolders userInfo:nil];
        completion(nil, error);
        return;
    }

    [self findItemsRecursivelyInFolders:rootFolders matchingPredicate:predicate callback:completion];
}

-(void)findItemsRecursivelyInFolders:(nonnull NSArray <id <CBLFileSystemFolderItem>> *)folders
                   matchingPredicate:(nullable CameraFileScanningPredicate)predicate
                            callback:(nonnull CameraFileScanningCompletion)completion {

    [self findItemsRecursivelyInFolders:folders
                      matchingPredicate:predicate
                   previouslyFoundItems:[NSArray new]
                               callback:completion];
}

-(void)findItemsRecursivelyInFolders:(nonnull NSArray <id <CBLFileSystemFolderItem>> *)folders
                   matchingPredicate:(nullable CameraFileScanningPredicate)predicate
                previouslyFoundItems:(nonnull NSArray <id <CBLFileSystemItem>> *)foundItems
                            callback:(nonnull CameraFileScanningCompletion)completion {

    if (folders.count == 0) {
        // We've run out of folders to load in this batch.
        completion(foundItems, nil);
        return;
    }

    NSMutableArray *foldersRemaining = [folders mutableCopy];
    id <CBLFileSystemFolderItem> thisFolder = foldersRemaining.firstObject;
    [foldersRemaining removeObjectAtIndex:0];

    [self findItemsRecursivelyInFolder:thisFolder
                     matchingPredicate:predicate
                              callback:^(NSArray <id <CBLFileSystemItem>> *items, NSError *error)
     {
        NSMutableArray *updatedItems = [foundItems mutableCopy];

        if (items.count > 0) {
            [updatedItems addObjectsFromArray:items];
        }

        if (error != nil) {
            completion(nil, error);
        } else {
            [self findItemsRecursivelyInFolders:foldersRemaining
                              matchingPredicate:predicate
                           previouslyFoundItems:updatedItems
                                       callback:completion];
        }
    }];
}

-(void)findItemsRecursivelyInFolder:(nonnull id <CBLFileSystemFolderItem>)folder
                  matchingPredicate:(nullable CameraFileScanningPredicate)predicate
                           callback:(nonnull CameraFileScanningCompletion)completion {

    [folder loadChildren:^(NSError *error) {

        if (error != nil) {
            completion(nil, error);
            return;
        }

        CameraFileScanningPredicate effectivePredicate = predicate;

        if (effectivePredicate == nil) {
            effectivePredicate = ^BOOL(id <CBLFileSystemItem> item) { return YES; };
        }

        __block NSMutableArray <id <CBLFileSystemItem>> *matchedItems = [NSMutableArray new];
        __block NSMutableArray <id <CBLFileSystemFolderItem>> *folders = [NSMutableArray new];

        for (id <CBLFileSystemItem> item in folder.children) {
            if ([item conformsToProtocol:@protocol(CBLFileSystemFolderItem)]) {
                [folders addObject:(id <CBLFileSystemFolderItem>)item];

            } else if (effectivePredicate(item)) {
                [matchedItems addObject:item];
            }
        }

        [self findItemsRecursivelyInFolders:folders
                          matchingPredicate:effectivePredicate
                                   callback:^(NSArray <id <CBLFileSystemItem>> *items, NSError *error)
        {
            if (items.count > 0) {
                [matchedItems addObjectsFromArray:items];
            }
            completion(matchedItems, error);
        }];

    }];
}

@end
