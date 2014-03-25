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
UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
float tol = 0.50;

@synthesize videoRenderer = _videoRenderer;
@synthesize videoView = _videoView;


- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
	// Get the current device angle
	float xx = -[acceleration x];
	float yy = [acceleration y];
	float zz = [acceleration z];
	float angle = atan2(yy, xx);
    UIInterfaceOrientation newOrientation = orientation;
    int android_orientation = 0;
    if( zz < -0.75 || zz > 0.75) return;
    /* Android rotation values
    * 0: Surface.ROTATION_0
    * 1: Surface.ROTATION_90
    * 2: Surface.ROTATION_180
    * 3: Surface.ROTATION_270
     */
    
	if(angle >= -2.25 + tol && angle <= -0.75 - tol) {
        newOrientation = UIInterfaceOrientationPortrait;
        android_orientation = 0;
    }
	else if(angle >= -0.75 + tol && angle <= 0.75 - tol) {
        newOrientation = UIInterfaceOrientationLandscapeRight;
        android_orientation = 1;
    }
	else if(angle >= 0.75 + tol && angle <= 2.25 - tol) {
        newOrientation = UIInterfaceOrientationPortraitUpsideDown;
        android_orientation = 2;
    }
	else if(angle <= -2.25 - tol || angle >= 2.25 + tol) {
        newOrientation = UIInterfaceOrientationLandscapeLeft;
        android_orientation = 3;
    }
    
    if( orientation != newOrientation){
        NSLog(@"%d -- %d  AO - %d", orientation, newOrientation, android_orientation);
        orientation = newOrientation;
        [_videoView sendVmRotation:android_orientation];
    }
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return NO;
}

- (NSInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

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
        NSLog(@"*** NO INTERNET connection found!");
    }

    UIAccelerometer *accel = [UIAccelerometer sharedAccelerometer];
    accel.delegate = self;
    //accel.updateInterval = 1.0f/60.0f;

    APPRTCAppDelegate *ad = (APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate];
    [ad launchSvmpAppClient];

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

- (void) videoReady {
    [_videoView cancelLoadingAndInitTouch];
}

- (BOOL) connectedToInternet
{
    NSString *URLString = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://www.google.com"]];
    return ( URLString != NULL ) ? YES : NO;
}


@end
