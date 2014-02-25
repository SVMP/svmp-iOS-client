//
//  iMASFlipsideViewController.m
//  APSampleApp
//
//  Created by Ganley, Gregg on 8/22/13.
//  Copyright (c) 2013 MITRE Corp. All rights reserved.
//

#import "iMASFlipsideViewController.h"
#import "iMASAppDelegate.h"

@interface iMASFlipsideViewController ()

@end

@implementation iMASFlipsideViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    iMASAppDelegate *appDelegate = (iMASAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate addMenu];

    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (IBAction)done:(id)sender
{
    [self.delegate flipsideViewControllerDidFinish:self];
}

@end
