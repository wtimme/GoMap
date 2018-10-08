//
//  LoginViewController.m
//  Go Map!!
//
//  Created by Bryce Cogswell on 12/19/12.
//  Copyright (c) 2012 Bryce Cogswell. All rights reserved.
//

#import "AppDelegate.h"
#import "EditorMapLayer.h"
#import "KeyChain.h"
#import "LoginViewController.h"
#import "MapView.h"
#import "OsmMapData.h"

@implementation LoginViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (IBAction)textFieldReturn:(id)sender
{
	[sender resignFirstResponder];
}

- (IBAction)textFieldDidChange:(id)sender
{
	_verifyButton.enabled = _username.text.length && _password.text.length;
}

- (IBAction)registerAccount:(id)sender
{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"https://www.openstreetmap.org/user/new"]];
}


- (IBAction)verifyAccount:(id)sender
{
	if ( _activityIndicator.isAnimating )
		return;

	AppDelegate * appDelegate = (id)[[UIApplication sharedApplication] delegate];
	appDelegate.userName		= [_username.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	appDelegate.userPassword	= [_password.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	_activityIndicator.color = UIColor.darkGrayColor;
	[_activityIndicator startAnimating];

	[appDelegate.mapView.editorLayer.mapData verifyUserCredentialsWithCompletion:^(NSString * errorMessage){
		[_activityIndicator stopAnimating];
		if ( errorMessage ) {

			// warn that email addresses don't work
			if ( [appDelegate.userName containsString:@"@"] ) {
				errorMessage = NSLocalizedString(@"login_error_provide_username_instead_of_email",nil);
			}
			UIAlertController * alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"login_error_alert_title",nil) message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
			[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"generic_ok",nil) style:UIAlertActionStyleCancel handler:nil]];
			[self presentViewController:alert animated:YES completion:nil];
		} else {
			// verifying credentials may update the appDelegate values when we subsitute name for correct case:
			_username.text	= appDelegate.userName;
			_password.text	= appDelegate.userPassword;
			[_username resignFirstResponder];
			[_password resignFirstResponder];

			UIAlertController * alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"login_successful_alert_title",nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
			[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"generic_ok",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
				[self.navigationController popToRootViewControllerAnimated:YES];
			}]];
			[self presentViewController:alert animated:YES completion:nil];
		}
	}];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	AppDelegate * appDelegate = (id)[[UIApplication sharedApplication] delegate];
	_username.text	= appDelegate.userName;
	_password.text	= appDelegate.userPassword;

	_verifyButton.enabled = _username.text.length && _password.text.length;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];

	AppDelegate * appDelegate = (id)[[UIApplication sharedApplication] delegate];
	appDelegate.userName		= [_username.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	appDelegate.userPassword	= [_password.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	[KeyChain setString:appDelegate.userName forIdentifier:@"username"];
	[KeyChain setString:appDelegate.userPassword forIdentifier:@"password"];
}

#pragma mark - Table view delegate

@end
