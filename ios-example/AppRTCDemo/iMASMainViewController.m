//
//  iMASMainViewController.m
//  APSampleApp
//
//  Created by Ganley, Gregg on 8/22/13.
//  Copyright (c) 2013 MITRE Corp. All rights reserved.
//

#import "iMASMainViewController.h"
#import "APViewController.h"
#import <SecureFoundation/SecureFoundation.h>

@interface iMASMainViewController ()

@end

@implementation iMASMainViewController

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 2; // Two columns for security
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent: (NSInteger)component
{
    return 3; // Both 3 right now
    
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row   forComponent:(NSInteger)component
{
    if(component == 0) return [self.encryptionTypes objectAtIndex:row];
    return [self.authTypes objectAtIndex:row];
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.encryptionTypes = [[NSArray alloc]  initWithObjects:@"None",@"SSL/TLS",@"Plain Certs", nil];
    self.authTypes = [[NSArray alloc] initWithObjects:@"Password", @"Token", @"Pass + Token", nil];
    self.hostText.delegate = self;
    self.passwordText.delegate = self;
    self.portText.delegate = self;
    self.userNameText.delegate = self;
    
    // Load up the form from the keychain
    NSData* hostData = [IMSKeychain securePasswordDataForService:@"host" account:@"1"];
    NSString * hostStr = [[NSString alloc] initWithData:hostData encoding:NSUTF8StringEncoding];
    self.hostText.text = hostStr;
    
    NSData* portData = [IMSKeychain securePasswordDataForService:@"port" account:@"1"];
    NSString * portStr = [[NSString alloc] initWithData:portData encoding:NSUTF8StringEncoding];
    self.portText.text = portStr;
    
    NSData* userData = [IMSKeychain securePasswordDataForService:@"user" account:@"1"];
    NSString * userStr = [[NSString alloc] initWithData:userData encoding:NSUTF8StringEncoding];
    self.userNameText.text = userStr;
    
    NSData* passData = [IMSKeychain securePasswordDataForService:@"pass" account:@"1"];
    NSString * passStr = [[NSString alloc] initWithData:passData encoding:NSUTF8StringEncoding];
    self.passwordText.text = passStr;

    NSData* encData = [IMSKeychain securePasswordDataForService:@"enc" account:@"1"];
    NSString * encStr = [[NSString alloc] initWithData:encData encoding:NSUTF8StringEncoding];
    [self.encryptionPicker selectRow:[encStr intValue] inComponent:0 animated:NO];

    NSData* authData = [IMSKeychain securePasswordDataForService:@"auth" account:@"1"];
    NSString * authStr = [[NSString alloc] initWithData:authData encoding:NSUTF8StringEncoding];
    [self.encryptionPicker selectRow:[authStr intValue] inComponent:1 animated:NO];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

-(void)viewDidAppear:(BOOL)animated{
    [self becomeFirstResponder];
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Flipside View


- (void)flipsideViewControllerDidFinish:(iMASFlipsideViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSInteger row;
    
    [IMSKeychain setSecurePassword:self.hostText.text forService:@"host" account:@"1"];
    [IMSKeychain setSecurePassword:self.portText.text forService:@"port" account:@"1"];
    [IMSKeychain setSecurePassword:self.userNameText.text forService:@"user" account:@"1"];
    [IMSKeychain setSecurePassword:self.passwordText.text forService:@"pass" account:@"1"];
    
    
    row = [self.encryptionPicker selectedRowInComponent:0];
    [IMSKeychain setSecurePassword:[NSString stringWithFormat:@"%d", row] forService:@"enc" account:@"1"];
    row = [self.encryptionPicker selectedRowInComponent:1];
    [IMSKeychain setSecurePassword:[NSString stringWithFormat:@"%d", row] forService:@"auth" account:@"1"];

    
    if ([[segue identifier] isEqualToString:@"showAlternate"]) {
        [[segue destinationViewController] setDelegate:self];
    }
}

//**
//**
//** RESET logic
//**

- (IBAction)resetPasscode:(id)sender {

    //** pop-up APview controller for questions
    APViewController *apc = [[APViewController alloc] initWithParameter:RESET_PASSCODE];
    apc.delegate = (id)self;
    [self presentViewController:apc animated:YES completion:nil];
}

- (void)validUserAccess:(APViewController *)controller {
    NSLog(@"MainView - validUserAccess - Delegate");
    //** callback for RESET
    [self dismissViewControllerAnimated:YES completion:nil];

}

//**
//** logout

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == [alertView cancelButtonIndex])
        return;
    
    NSLog(@"User Logged out");
    IMSCryptoManagerPurge();
    exit(0);
}

- (IBAction)logout:(id)sender {
    
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:@"Logout, are you sure?" message:nil delegate:self
                          cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
    [alert show];
}

@end
