/*
 * libjingle
 * Copyright 2013, Google Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 *
 * Last updated by: Gregg Ganley
 * Nov 2013
 *
 */

#import "APPRTCViewController.h"
#import "APPRTCAppDelegate.h"
#import "RTCVideoRenderer.h"
#import "VideoView.h"
#import <QuartzCore/QuartzCore.h>
#import <SecureFoundation/SecureFoundation.h>

@interface APPRTCViewController ()

@end

@implementation APPRTCViewController

BOOL isShowingLandscapeView = NO;
UIButton *button;

@synthesize videoRenderer = _videoRenderer;
@synthesize videoView = _videoView;

- (void)disconnectMenu:(UIButton*)button
{
     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Disconnect device?"
     message:@"Do you want to disconnect from the android device?"
     delegate:self
     cancelButtonTitle:@"No"
     otherButtonTitles:@"Yes", nil];
     [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
    {
        [UIApplication sharedApplication];
        APPRTCAppDelegate *appDelegate = (APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate onClose];
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;

    if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
        toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        button.frame = CGRectMake(screenHeight - 22, screenWidth - 42, 22.0, 22.0);
    } else if (toInterfaceOrientation == UIInterfaceOrientationPortrait ||
               toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
        button.frame = CGRectMake(screenWidth - 22, screenHeight - 42, 22.0, 22.0);
    }
}

- (void)viewDidLoad {
  [super viewDidLoad];
    
    if ([self connectedToInternet] == NO) {
        NSLog(@"NO INTERNET connection!");
    }

    
    //** get the host and port data from the iMAS keychain
    NSData* hostData = [IMSKeychain securePasswordDataForService:@"host" account:@"1"];
    NSString * hostStr = [[NSString alloc] initWithData:hostData encoding:NSUTF8StringEncoding];
    NSData* portData = [IMSKeychain securePasswordDataForService:@"port" account:@"1"];
    NSString * portStr = [[NSString alloc] initWithData:portData encoding:NSUTF8StringEncoding];
    
    //** connect to SVMP proxy server
    NSString *url =
        [NSString stringWithFormat:@"apprtc://%@:%@/?r=", hostStr, portStr];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    
    //** Add video view to this view
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height-80);
    _videoView = [[VideoView alloc] initWithFrame:frame];
    [self.view addSubview:_videoView];
    
    //** add Disconnect button
    button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button addTarget:self action:@selector(disconnectMenu:) forControlEvents:UIControlEventTouchUpInside];
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    [button setTitle:@"i" forState:UIControlStateNormal];
    button.frame = CGRectMake(screenWidth - 22, screenHeight - 42, 22.0, 22.0);
    [self.view addSubview:button];

    
}


- (BOOL) connectedToInternet
{
    NSString *URLString = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://www.google.com"]];
    return ( URLString != NULL ) ? YES : NO;
}


@end
