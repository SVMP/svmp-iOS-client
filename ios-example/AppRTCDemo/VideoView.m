//
//  VideoView.m
//
/*
 *
 * Last updated by: Gregg Ganley
 * Nov 2013
 *
 */


#import "VideoView.h"
#import "APPRTCAppDelegate.h"

#import "RTCVideoRenderer.h"
#import <QuartzCore/QuartzCore.h>

@interface VideoView () {
    UIInterfaceOrientation _videoOrientation;
    UIColor *_color;
    
    RTCVideoTrack *_track;
    RTCVideoRenderer *_renderer;
}
@property (nonatomic, retain) UIView<RTCVideoRenderView> *renderView;
@property (nonatomic, retain) UIImageView *placeholderView;
@end

@implementation VideoView
    float xScaleFactor;
    float yScaleFactor;
    bool gotScreenInfo = false;
    float firstX = 0.0;
    float firstY = 0.0;
    UILabel *loadingLabel;

//** Resize the video
#define VIDEO_WIDTH 320
#define VIDEO_HEIGHT 470

-(void) disconnectMenu {
    NSLog(@"HERE");
}

static void init(VideoView *self) {
    
    UIView<RTCVideoRenderView> *renderView = [RTCVideoRenderer newRenderViewWithFrame:CGRectMake(200, 100, 240, 180)];
    [self setRenderView:renderView];
    UIImageView *placeholderView = [[UIImageView alloc] initWithFrame:[renderView frame]];
    [self setPlaceholderView:placeholderView];
    NSDictionary *views = NSDictionaryOfVariableBindings(renderView, placeholderView);
    NSDictionary *metrics = @{@"VIDEO_WIDTH" : @(VIDEO_WIDTH), @"VIDEO_HEIGHT" : @(VIDEO_HEIGHT)};
    
    [placeholderView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:placeholderView];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:placeholderView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:placeholderView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];

    
    [renderView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:renderView];
    [renderView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[renderView(VIDEO_WIDTH)]" options:0 metrics:metrics views:views]];
    [renderView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[renderView(VIDEO_HEIGHT)]" options:0 metrics:metrics views:views]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:renderView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:renderView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    

    //** rounded corners of frame
    // [[self layer] setCornerRadius:VIDEO_HEIGHT/2.0];
    [[self layer] setMasksToBounds:YES];
    [self setBackgroundColor:[UIColor darkGrayColor]];
    
    //** hack in LOADING text...
    loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, 150, 24)];
    
    [loadingLabel setTextColor:[UIColor whiteColor]];
    [loadingLabel setBackgroundColor:[UIColor darkGrayColor]];
    [loadingLabel setFont:[UIFont fontWithName: @"Trebuchet MS" size: 24.0f]];
    [loadingLabel setText:@"Loading..."];
    loadingLabel.center = CGPointMake(VIDEO_WIDTH/2, VIDEO_HEIGHT/2);
    [self addSubview:loadingLabel];

    
    //** add tap gesture recognizer
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    recognizer.delegate = self;
    [self addGestureRecognizer:recognizer];
    
    //** add single finger touch and move
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMove:)];
	[panRecognizer setMinimumNumberOfTouches:1];
	[panRecognizer setMaximumNumberOfTouches:1];
	[panRecognizer setDelegate:self];
	[self addGestureRecognizer:panRecognizer];
    
    //** add two finger tap - for Android back button
    UITapGestureRecognizer *twoTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    [twoTapRecognizer setNumberOfTouchesRequired:2];
        //[twoTapRecognizer numberOfTapsRequired:2]; // setNumberOfTapsRequired:2];
    [twoTapRecognizer setDelegate:self];
	[self addGestureRecognizer:twoTapRecognizer];
    
}

- (BOOL)handleScreenInfoResponse:(Response *) msg {
    NSLog(@"ScreenInfo response START");
    if ( ![msg hasScreenInfo] )
        return false;

    
    int x = [[msg screenInfo] x];
    int y = [[msg screenInfo] y];
    NSLog(@"Got the ServerInfo: xsize=%d ysize=%d" , x, y);
    xScaleFactor = (float)x/(float)VIDEO_WIDTH;
    yScaleFactor = (float)y/(float)VIDEO_HEIGHT;
    NSLog(@"Scale factor: %.2f ; %.2f", xScaleFactor, yScaleFactor);
    
    gotScreenInfo = true;

    return true;
}

- (void)sendScreenInfo {
    //** send SCREENINFO request
    APPRTCAppDelegate *ad = (APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate];
    Request_Builder* msg = [Request builder];
    [msg setType:Request_RequestTypeScreeninfo];
    Request* request = [msg build];
    
    [ad.client sendSVMPMessage:request];
    NSLog(@"Sent screen info request");
}


- (void)handleMove:(UIPanGestureRecognizer *)recognizer {
    TouchEvent_Builder *eventMsg;
    TouchEvent_PointerCoords_Builder *p;
    Request_Builder *msg;
    Request *request;
    
    if (!gotScreenInfo) return;
    
    NSLog(@"handleMove");
    
    APPRTCAppDelegate *ad = (APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    CGPoint translation = [recognizer translationInView:self];

    //**
    //** START
    if ([(UIPanGestureRecognizer*)recognizer state] == UIGestureRecognizerStateBegan) {
        firstX = [recognizer locationInView:self].x;
        firstY = [recognizer locationInView:self].y;
        NSLog(@"START x: %.2f  y: %.2f", firstX, firstY);
        
        //** build start of finger movement msg
        p = [TouchEvent_PointerCoords builder];
        eventMsg = [TouchEvent builder];
        [eventMsg setAction:0]; // android ACTION_DOWN(0)
        
        //** add location of finger
        [p clear];
        [p setId:0]; //** id of single finger down
        [p setX:firstX];
        [p setY:firstY];
        [eventMsg addItems:[p build]];
        
        msg = [Request builder];
        [msg setType:Request_RequestTypeTouchevent];
        [msg setTouch:[eventMsg build]];
        request = [msg build];
        
        [ad.client sendSVMPMessage:request];

        return;
    }

    //**
    //** end movement
    if ([(UIPanGestureRecognizer*)recognizer state] == UIGestureRecognizerStateEnded) {
        float endX = [recognizer locationInView:self].x;
        float endY = [recognizer locationInView:self].y;
        NSLog(@"END x: %.2f  y: %.2f", endX, endY);
        
        
        //** create and send event msg
        p = [TouchEvent_PointerCoords builder];
        eventMsg = [TouchEvent builder];
        [eventMsg setAction:1]; // android ACTION_UP(1)
        
        //** add location of finger
        [p clear];
        [p setId:0];
        [p setX:endX];
        [p setY:endY];
        [eventMsg addItems:[p build]];
        
        msg = [Request builder];
        [msg setType:Request_RequestTypeTouchevent];
        [msg setTouch:[eventMsg build]];
        request = [msg build];
        
        [ad.client sendSVMPMessage:request];
        return;
    }
    
    //**
    //** movement
    NSLog(@"MOVE x: %.2f  y: %.2f", translation.x, translation.y);

    //** create and send event msg
    p = [TouchEvent_PointerCoords builder];
    eventMsg = [TouchEvent builder];
    [eventMsg setAction:2]; // android ACTION_MOVE(2)
    
    //** add location of finger
    [p clear];
    [p setId:0];
    [p setX:(firstX + translation.x)];
    [p setY:(firstY + translation.y)];
    [eventMsg addItems:[p build]];
    
    msg = [Request builder];
    [msg setType:Request_RequestTypeTouchevent];
    [msg setTouch:[eventMsg build]];
    request = [msg build];
    
    [ad.client sendSVMPMessage:request];

}

int once = 1;
//** handle tap
- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    TouchEvent_Builder *eventMsg;
    TouchEvent_PointerCoords_Builder *p;
    Request_Builder *msg;
    Request *request;
    
    if (once) {
        [self sendScreenInfo];
        once = 0;
        //** remove loading label
        [loadingLabel removeFromSuperview];
        return;
    }
    if (!gotScreenInfo) return;
    
    CGPoint tapPoint = [recognizer locationInView:self];
    int tapX = (int) tapPoint.x;
    int tapY = (int) tapPoint.y;
    NSLog(@"TAPPED X:%d Y:%d", tapX, tapY);
    
    APPRTCAppDelegate *ad = (APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    eventMsg = [TouchEvent builder];
    p = [TouchEvent_PointerCoords builder];
    
    //** SEND DOWN
    [eventMsg setAction:0]; // android ACTION_DOWN(0)
    float adjX = tapX * xScaleFactor;
    float adjY = tapY * yScaleFactor;
    [p clear];
    [p setId:0];
    [p setX:adjX];
    [p setY:adjY];
    [eventMsg addItems:[p build]];
    NSLog(@"TOUCH DOWN %.2f ; %.2f", adjX, adjY);
    
    msg = [Request builder];
    [msg setType:Request_RequestTypeTouchevent];
    [msg setTouch:[eventMsg build]];
    request = [msg build];
    
    [ad.client sendSVMPMessage:request];
    
    
    //** send UP
    
    //** create and send event msg
    p = [TouchEvent_PointerCoords builder];
    eventMsg = [TouchEvent builder];
    [eventMsg setAction:1]; // android ACTION_UP(1)
    
    //** add location of finger
    [p clear];
    [p setId:0];
    [p setX:adjX];
    [p setY:adjY];
    [eventMsg addItems:[p build]];
    NSLog(@"TOUCH DOWN %.2f ; %.2f", adjX, adjY);
    
    msg = [Request builder];
    [msg setType:Request_RequestTypeTouchevent];
    [msg setTouch:[eventMsg build]];
    request = [msg build];
    
    [ad.client sendSVMPMessage:request];
}



//** handle tap
int x = 0;
- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
    TouchEvent_Builder *eventMsg;
    TouchEvent_PointerCoords_Builder *p;
    Request_Builder *msg;
    Request *request;
    
    if (!gotScreenInfo) return;

    //** make this equiv to the android BACK button - for now
    
    APPRTCAppDelegate *ad = (APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
/*    eventMsg = [TouchEvent builder];
    p = [TouchEvent_PointerCoords builder];
    
    //** SEND DOWN
    [eventMsg setAction:8]; // android BUTTON_BACK(8)
    NSLog(@"DOUBLE DOWN - BACK");
    
    msg = [Request builder];
    [msg setType:Request_RequestTypeTouchevent];
    [msg setTouch:[eventMsg build]];
    request = [msg build];
  */
    
    // create a RotationInfo Builder
    RotationInfo_Builder *riBuilder = [RotationInfo builder];
    [riBuilder setRotation: (x++ % 4)];
    
    // pack RotationInfo into Request wrapper
    msg = [Request builder];
    [msg setType:Request_RequestTypeRotationInfo];
    [msg setRotationInfo:[riBuilder build]];
    request = [msg build];

    [ad.client sendSVMPMessage:request];
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        init(self);
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        init(self);
    }
    return self;
}

-(UIImage *)placeholderImage {
    return [[self placeholderView] image];
}

- (void)setPlaceholderImage:(UIImage *)placeholderImage {
    [[self placeholderView] setImage:placeholderImage];
}

- (UIInterfaceOrientation)videoOrientation {
    return _videoOrientation;
}

-(CGSize)intrinsicContentSize {
    // We add a bit of a buffer to keep the video from showing out of our border
    CGFloat borderSize = 0; //[[self layer] borderWidth];
    return CGSizeMake(VIDEO_HEIGHT + borderSize - 1, VIDEO_HEIGHT + borderSize - 1);
}

- (void)setVideoOrientation:(UIInterfaceOrientation)videoOrientation {
    if (_videoOrientation != videoOrientation) {
        _videoOrientation = videoOrientation;
                
        CGFloat angle;
        switch (videoOrientation) {
            case UIInterfaceOrientationPortrait:
                angle = M_PI_2;
                break;
            case UIInterfaceOrientationPortraitUpsideDown:
                angle = -M_PI_2;
                break;
            case UIInterfaceOrientationLandscapeLeft:
                angle = M_PI;
                break;
            case UIInterfaceOrientationLandscapeRight:
                angle = 0;
                break;
        }
        // The video comes in mirrored. x=-1 flips the video around
        CGAffineTransform xform = CGAffineTransformMakeScale(-1, 1);
        xform = CGAffineTransformRotate(xform, angle);
        [[self renderView] setTransform:xform];
    }
}

- (void)renderVideoTrackInterface:(RTCVideoTrack *)videoTrack {
    [self stop:nil];
    
    _track = videoTrack;
    
    if (_track) {
        if (!_renderer) {
            _renderer = [[RTCVideoRenderer alloc] initWithRenderView:[self renderView]];
        }
        [_track addRenderer:_renderer];
        [self resume:self];
    }
    //** flip the video over
    [self setVideoOrientation:UIInterfaceOrientationLandscapeLeft];
    [self setVideoOrientation:UIInterfaceOrientationPortrait];
    [self setVideoOrientation:UIInterfaceOrientationLandscapeLeft];
}

#if 0
- (void)orientationChanged:(NSNotification *)notification
{
        UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
        CGRect rect = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.height, [[UIScreen mainScreen] bounds].size.width);
        
        
        switch (deviceOrientation) {
            case 1:
                [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationPortrait animated:NO];
                [UIView beginAnimations:nil context:NULL];
                [UIView setAnimationDuration:0.1];
                self.view.transform = CGAffineTransformMakeRotation(0);
                self.view.bounds = [[UIScreen mainScreen] bounds];
                [UIView commitAnimations];
                break;
            case 2:
                [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationPortraitUpsideDown animated:NO];
                [UIView beginAnimations:nil context:NULL];
                [UIView setAnimationDuration:0.1];
                self.view.transform = CGAffineTransformMakeRotation(-M_PI);
                self.view.bounds = [[UIScreen mainScreen] bounds];
                [UIView commitAnimations];
                break;
            case 3:
                [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationLandscapeRight animated:NO];
                //rect = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.height, [[UIScreen mainScreen] bounds].size.width);
                [UIView beginAnimations:nil context:NULL];
                [UIView setAnimationDuration:0.1];
                self.view.transform = CGAffineTransformMakeRotation(M_PI_2);
                self.view.bounds = rect;
                [UIView commitAnimations];
                break;
            case 4:
                [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationLandscapeLeft animated:NO];
                [UIView beginAnimations:nil context:NULL];
                [UIView setAnimationDuration:0.1];
                //rect = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.height, [[UIScreen mainScreen] bounds].size.width);
                self.view.transform = CGAffineTransformMakeRotation(-M_PI_2);
                self.view.bounds = rect;
                [UIView commitAnimations];
                break;
                
            default:
                break;
        }
}
#endif
      
      
      
-(void)pause:(id)sender {
    [_renderer stop];
}

-(void)resume:(id)sender {
    [_renderer start];
}

- (void)stop:(id)sender {
    [_track removeRenderer:_renderer];
    [_renderer stop];
}

#if 0
- (UIImage*)snapshot {
    UIImage *unorientedSnapshot = [[self renderView] snapshot];
    UIImage *snapshot = nil;
    
    // apply view xform into snapshot. we do this rather than keep the orientation as metadata in UIImage because some parts of UIKit don't manage to respect the metadata properly (UIImagePNGRepresentation, UIButton's auto-darkening on press)
    CGAffineTransform xform = [[self renderView] transform];
    if (!CGAffineTransformEqualToTransform(xform, CGAffineTransformIdentity)) {
        CGSize xformedSize = CGRectApplyAffineTransform([unorientedSnapshot us_bounds], xform).size;
        UIGraphicsBeginImageContext(xformedSize);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextConcatCTM(ctx, xform);
        [unorientedSnapshot drawInRect:CGContextGetClipBoundingBox(ctx)];
        snapshot = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    } else {
        snapshot = unorientedSnapshot;
    }
    
    return snapshot;
}

#endif
@end
