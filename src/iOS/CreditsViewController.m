//
//  CreditsViewController.m
//  Go Map!!
//
//  Created by Bryce Cogswell on 12/25/12.
//  Copyright (c) 2012 Bryce Cogswell. All rights reserved.
//

#import "CreditsViewController.h"
#import <QuartzCore/QuartzCore.h>

@implementation CreditsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _textView.editable = NO;
    _textView.layer.cornerRadius = 10.0;
}

@end
