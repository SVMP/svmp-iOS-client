//
//  APViewController.h
//  APComplexPassEncryt
//
//  Created by ct on 4/4/13.
//  Copyright (c) 2013 Mitre. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AppPassword/AppPassword.h>
#import <AppPassword/APPass.h>

#import <SecureFoundation/SecureFoundation.h>

#define RESET_PASSCODE 1
#define LOGOUT 2

@class APViewController;

@protocol APViewControllerDelegate
- (void)validUserAccess:(APViewController *)controller;
@end

@interface APViewController : UIViewController <APPassProtocol>
-(id)initWithParameter: (BOOL)reset;

@property (weak, nonatomic) id <APViewControllerDelegate> delegate;


@end


