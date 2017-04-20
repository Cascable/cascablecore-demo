//
//  FilesystemViewController.m
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-20.
//
//

#import "FilesystemViewController.h"
#import "FilesystemItemCell.h"
#import "CameraFileScanning.h"
#import "Macros.h"

@interface FilesystemViewController ()
@property (nonatomic, readwrite) id <CBLCamera> camera;
@property (nonatomic, readwrite) NSArray <id <CBLFileSystemItem>> *items;
@end

@implementation FilesystemViewController

-(void)setupUIForCamera:(id <CBLCamera>)camera {

    self.camera = camera;

    // CameraFileScanning is a helper class provided with this demo app that iterates through
    // the camera's directory structure and extracts files that the called might be interested in.
    CameraFileScanning *scanner = [CameraFileScanning sharedInstance];

    [scanner scanForFilesInCamera:self.camera matchingPredicate:^BOOL(id <CBLFileSystemItem> item) {
        // We're only interested in images and items that don't have loaded metadata (they're probably images too).
        return item.isKnownImageType || !item.metadataLoaded;

    } callback:^(NSArray <id <CBLFileSystemItem>> *items, NSError *error) {
        NSLog(@"%@: Camera scan got %@ matched items", THIS_FILE, @(items.count));
        self.items = items;
        [self.tableView reloadData];
    }];
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
