//
//  FilesystemViewController.m
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-20.
//  Copyright © 2017 Cascable AB.
//  For license information, see LICENSE.md.

#import "FilesystemViewController.h"
#import "FilesystemItemCell.h"
#import "CameraFileScanning.h"
#import "Macros.h"

@interface FilesystemViewController ()
@property (strong, nonatomic) IBOutlet UIView *busyView;
@property (nonatomic, readwrite) id <CBLCamera> camera;
@property (nonatomic, readwrite) NSArray <id <CBLFileSystemItem>> *items;
@property (nonatomic, readwrite) IBOutlet UIProgressView *progressView;
@end

@implementation FilesystemViewController

-(void)setupUIForCamera:(id <CBLCamera>)camera {

    self.camera = camera;

    [self loadViewIfNeeded];
    [self showBusyOverlay];

    // CameraFileScanning is a helper class provided with this demo app that iterates through
    // the camera's directory structure and extracts files that the called might be interested in.
    // You're welcome to use this in your own apps, but it may not provide the best UI
    // experience — since it takes an all-or-nothing approach, if the camera has a lot of files
    // your users will see nothing for a long time.
    CameraFileScanning *scanner = [CameraFileScanning sharedInstance];

    NSProgress *progress = [scanner scanForFilesInCamera:self.camera matchingPredicate:^BOOL(id <CBLFileSystemItem> item) {
        // We're only interested in images, videos, and items that don't have loaded metadata (they're probably images or videos too).
        return item.isKnownImageType || item.isKnownVideoType || !item.metadataLoaded;

    } callback:^(NSArray <id <CBLFileSystemItem>> *items, NSError *error) {
        NSLog(@"%@: Camera scan got %@ matched items", THIS_FILE, @(items.count));
        self.items = items;
        [self hideBusyOverlay];
        [self.tableView reloadData];
    }];

    if (progress == nil) {
        self.progressView.hidden = YES;
    } else {
        self.progressView.observedProgress = progress;
    }
}

#pragma mark - Lifecycle

-(void)viewDidLoad {
    [super viewDidLoad];

    // Since our busy overlay is a floating view in the storyboard, it needs a little setup.
    self.busyView.translatesAutoresizingMaskIntoConstraints = NO;
    self.busyView.layer.cornerRadius = 20.0;
    self.busyView.layer.masksToBounds = YES;

    [self.busyView addConstraint:[NSLayoutConstraint constraintWithItem:self.busyView
                                                              attribute:NSLayoutAttributeWidth
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1.0
                                                               constant:200.0]];

    [self.busyView addConstraint:[NSLayoutConstraint constraintWithItem:self.busyView
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1.0
                                                               constant:200.0]];
}

-(void)showBusyOverlay {
    [self.busyView removeFromSuperview];
    [self.view addSubview:self.busyView];

    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.busyView
                                                          attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeCenterX
                                                         multiplier:1.0 constant:0.0]];

    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.busyView
                                                          attribute:NSLayoutAttributeCenterY
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeCenterY
                                                         multiplier:1.0 constant:0.0]];
}

-(void)hideBusyOverlay {
    [self.busyView removeFromSuperview];
}

#pragma mark - Table view data source

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FilesystemItemCell *cell = [tableView dequeueReusableCellWithIdentifier:@"itemCell" forIndexPath:indexPath];
    cell.item = self.items[indexPath.row];
    return cell;
}

-(BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

@end
