//
//  iMASMainViewController.h
//  APSampleApp
//
//  Created by Ganley, Gregg on 8/22/13.
//  Copyright (c) 2013 MITRE Corp. All rights reserved.
//

#import "iMASFlipsideViewController.h"
#import "APPRTCViewController.h"

#import <CoreData/CoreData.h>

@interface iMASMainViewController : UIViewController <iMASFlipsideViewControllerDelegate, UIPickerViewDataSource,UIPickerViewDelegate,UITextFieldDelegate>

@property (strong, nonatomic) NSArray *encryptionTypes;
@property (strong, nonatomic) NSArray *authTypes;
@property (strong, nonatomic) IBOutlet UITextField *hostText;
@property (strong, nonatomic) IBOutlet UITextField *portText;
@property (strong, nonatomic) IBOutlet UITextField *userNameText;
@property (strong, nonatomic) IBOutlet UITextField *passwordText;
@property (strong, nonatomic) IBOutlet UIButton *connectButton;
@property(strong,nonatomic)APPRTCViewController *secondViewController;
- (IBAction)connectTouched:(id)sender;


@property (strong, nonatomic) IBOutlet UIPickerView *encryptionPicker;

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@end
