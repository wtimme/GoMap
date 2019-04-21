//
//  HtmlAlertViewController.h
//  Go Map!!
//
//  Created by Bryce Cogswell on 11/11/15.
//  Copyright © 2015 Bryce Cogswell. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HtmlAlertViewController : UIViewController <UITextViewDelegate> {
    NSMutableArray *_callbackList;
}

@property(assign, nonatomic) IBOutlet UIView *popup;
@property(assign, nonatomic) IBOutlet UILabel *heading;
@property(assign, nonatomic) IBOutlet UITextView *text;
@property(assign, nonatomic) IBOutlet UISegmentedControl *buttonBar;

@property(copy, nonatomic) NSString *htmlText;

- (void)addButton:(NSString *)label callback:(void (^)(void))callback;

@end
