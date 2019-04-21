//
//  POIDetailsViewController.h
//  Go Map!!
//
//  Created by Bryce Cogswell on 12/10/12.
//  Copyright (c) 2012 Bryce Cogswell. All rights reserved.
//

#import "CommonTagList.h"
#import "POITypeViewController.h"
#import <UIKit/UIKit.h>

@class OsmBaseObject;
@class CommonTagList;

@interface POICommonTagsViewController : UITableViewController <UITextFieldDelegate, POITypeViewControllerDelegate> {
    CommonTagList *_tags;
    IBOutlet UIBarButtonItem *_saveButton;
    BOOL _keyboardShowing;
}
@property(nonatomic) CommonTagGroup *drillDownGroup;

- (IBAction)textFieldReturn:(id)sender;

- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;

@end
