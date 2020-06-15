//
//  FilesystemItemCell.m
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-20.
//  Copyright © 2017 Cascable AB.
//  For license information, see LICENSE.md.

#import "FilesystemItemCell.h"

typedef NS_ENUM(NSUInteger, ItemLoadingState) {
    ItemLoadingStateStart = 0,
    ItemLoadingStateLoadingMetadata = 1,
    ItemLoadingStateLoadingThumbnail = 2,
    ItemLoadingStateDone = 3
};

@interface FilesystemItemCell ()
@property (weak, nonatomic) IBOutlet UILabel *fileNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingSpinner;
@property (nonatomic) ItemLoadingState loadingState;
@property (nonatomic) NSDateFormatter *dateFormatter;
@end

@implementation FilesystemItemCell

-(void)awakeFromNib {
    [super awakeFromNib];
    self.dateFormatter = [NSDateFormatter new];
    self.dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    self.dateFormatter.timeStyle = NSDateFormatterShortStyle;
}

-(void)setItem:(id<CBLFileSystemItem>)item {
    _item = item;
    self.loadingState = ItemLoadingStateStart;
    [self advanceLoadingState];
}

-(void)advanceLoadingState {

    // File system items are very lazy — they never start with any image properties (thumbnail, preview)
    // loaded, and they sometimes don't even have basic metadata like filename etc.

    // To deal with this, we'll build a little state machine that goes [start -> load metadata -> load thumbnail -> done].

    if (self.loadingState < ItemLoadingStateDone) {
        self.loadingState += 1;
    }

    [self updateUIForState:self.loadingState];

    switch (self.loadingState) {
        case ItemLoadingStateLoadingMetadata:
            [self loadMetadataThenAdvanceState];
            break;

        case ItemLoadingStateLoadingThumbnail:
            [self loadThumbnailThenAdvanceState];

        default:
            break;
    }
}

-(void)loadMetadataThenAdvanceState {

    if (self.item.metadataLoaded) {
        // If the metadata is already loaded, we're good.
        [self advanceLoadingState];
        return;
    }

    // It's possible that the cell will be recycled while we're loading (say, if the user scrolls away), so
    // we should keep track of this so we don't clash metadata.
    id <CBLFileSystemItem> itemAtStartOfStep = self.item;

    [self.item loadMetadata:^(NSError *error) {
        if (error != nil) { NSLog(@"WARNING: Got error when loading metadata: %@", error); }
        if (self.item != itemAtStartOfStep) {
            return;
        } else {
            [self advanceLoadingState];
        }
    }];
}

-(void)loadThumbnailThenAdvanceState {

    [self.item fetchThumbnailWithPreflightBlock:^BOOL(id <CBLFileSystemItem> item) {
        // The preflight block gets called just before the image starts to load. Since cameras
        // tend to queue requests, it may be a little while before it gets around to loading this
        // thumbnail. The preflight block allows us to cancel the request if it's not needed any
        // more — for instance, if the user has already scrolled away.
        return item == self.item;

    } thumbnailDeliveryBlock:^(id <CBLFileSystemItem> item, NSError *error, NSData *imageData) {
        if (error != nil) { NSLog(@"WARNING: Got error when loading thumbnail: %@", error); }

        if (item != self.item) {
            return;
        }

        if (imageData != nil) {
            UIImage *image = [UIImage imageWithData:imageData];
            self.thumbnailImageView.image = image;
        }

        [self advanceLoadingState];
    }];
}

-(void)updateUIForState:(ItemLoadingState)state {

    if (state <= ItemLoadingStateLoadingMetadata) {
        // At this point, we have nothing!
        self.thumbnailImageView.image = nil;
        self.fileNameLabel.text = @"Loading…";
        self.dateLabel.text = @"";
        [self.loadingSpinner startAnimating];

    } else if (state == ItemLoadingStateLoadingThumbnail) {
        // At this point, we should have some text metadata.
        self.fileNameLabel.text = self.item.name;
        if (self.item.dateCreated == nil) {
            self.dateLabel.text = @"Unknown Date";
        } else {
            self.dateLabel.text = [self.dateFormatter stringFromDate:self.item.dateCreated];
        }

    } else if (state >= ItemLoadingStateDone) {
        // We should have everything!
        [self.loadingSpinner stopAnimating];
    }
}

@end
