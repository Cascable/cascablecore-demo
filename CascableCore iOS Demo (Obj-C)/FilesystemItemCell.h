//
//  FilesystemItemCell.h
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-20.
//
//

#import <UIKit/UIKit.h>
@import CascableCore;

@interface FilesystemItemCell : UITableViewCell

@property (nonatomic, readwrite) id <CBLFileSystemItem> item;

@end
