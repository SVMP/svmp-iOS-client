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
    loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake(32, 32, 250, 35)];
    
    [loadingLabel setTextColor:[UIColor whiteColor]];
    [loadingLabel setBackgroundColor:[UIColor darkGrayColor]];
    [loadingLabel setFont:[UIFont fontWithName: @"Trebuchet MS" size: 18.0f]];
    [loadingLabel setText:@"Loading... (tap to dismiss)"];
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
    //UITapGestureRecognizer *twoTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    //[twoTapRecognizer setNumberOfTouchesRequired:2];
    //[twoTapRecognizer setDelegate:self];
	//[self addGestureRecognizer:twoTapRecognizer];
    
    UIPinchGestureRecognizer *twoFingerPinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self
            action:@selector(twoFingerPinch:)];
    [twoFingerPinch setDelegate:self];
    [self addGestureRecognizer:twoFingerPinch];
}


//******************************
//******************************
//**
//**
- (void) cancelLoadingAndInitTouch {
    //** return for now, not working, needs debug
    return;
    /*
    //** init with Android VM
    [self sendScreenInfo];

    //** remove loading label
    [loadingLabel removeFromSuperview];

    return; */
}


//******************************
//******************************
//**
//**
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


//******************************
//******************************
//**
//**
- (void)sendScreenInfo {
    //** send SCREENINFO request
    APPRTCAppDelegate *ad = (APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate];
    Request_Builder* msg = [Request builder];
    [msg setType:Request_RequestTypeScreeninfo];
    Request* request = [msg build];
    
    [ad.client sendSVMPMessage:request];
    NSLog(@"Sent screen info request");
}


//******************************
//******************************
//**
//** MOVE
//**
- (void)handleMove:(UIPanGestureRecognizer *)recognizer {
    TouchEvent_Builder *eventMsg;
    TouchEvent_PointerCoords_Builder *p;
    Request_Builder *msg;
    Request *request;
    
    if (!gotScreenInfo) return;
    
   // NSLog(@"handleMove");
    
    APPRTCAppDelegate *ad = (APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    CGPoint translation = [recognizer translationInView:self];

    //**
    //** START
    if ([(UIPanGestureRecognizer*)recognizer state] == UIGestureRecognizerStateBegan) {
        firstX = [recognizer locationInView:self].x;
        firstY = [recognizer locationInView:self].y;
        //NSLog(@"START x: %.2f  y: %.2f", firstX, firstY);
        
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
        //NSLog(@"END x: %.2f  y: %.2f", endX, endY);
        
        
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
    //NSLog(@"MOVE x: %.2f + %.2f  y: %.2f + %.2f", firstX, translation.x, firstY, translation.y);

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

//******************************
//******************************
//**
//**  TAP
//**
int once = 1; //disable
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
    //NSLog(@"TAPPED X:%d Y:%d", tapX, tapY);
    
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
    //NSLog(@"TOUCH DOWN %.2f ; %.2f", adjX, adjY);
    
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
    //NSLog(@"TOUCH DOWN %.2f ; %.2f", adjX, adjY);
    
    msg = [Request builder];
    [msg setType:Request_RequestTypeTouchevent];
    [msg setTouch:[eventMsg build]];
    request = [msg build];
    
    [ad.client sendSVMPMessage:request];
}


#if 0
int x = 0;
- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
    TouchEvent_Builder *eventMsg;
    TouchEvent_PointerCoords_Builder *p;
    Request_Builder *msg;
    Request *request;
    APPRTCAppDelegate *ad = (APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if (!gotScreenInfo) return;
    
    NSLog(@"DOUBLE DOWN - ");
    

#if 0
    eventMsg = [TouchEvent builder];
    p = [TouchEvent_PointerCoords builder];
    
    //** SEND DOWN
    [eventMsg setAction:8]; // android BUTTON_BACK(8)

    
    msg = [Request builder];
    [msg setType:Request_RequestTypeTouchevent];
    [msg setTouch:[eventMsg build]];
    request = [msg build];
    [ad.client sendSVMPMessage:request];
    
#endif
    
}
#endif


//******************************
//******************************
//**
//**  Pinch and Zoom
//**
- (void)twoFingerPinch:(UIPinchGestureRecognizer *)recognizer  {
    TouchEvent_Builder *eventMsg;
    TouchEvent_PointerCoords_Builder *p;
    Request_Builder *msg;
    Request *request;
    APPRTCAppDelegate *ad = (APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if (!gotScreenInfo) return;
    if( recognizer.numberOfTouches != 2) return;
    //NSLog(@"twoFingerPinch");
    
    //** get XY of location of fingers (points)
    CGPoint point1 = [recognizer locationOfTouch:0 inView:self];
    CGPoint point2 = [recognizer locationOfTouch:1 inView:self];

    //** scale to android screen
    float scaledX1 = point1.x * xScaleFactor;
    float scaledY1 = point1.y * yScaleFactor;
    float scaledX2 = point2.x * xScaleFactor;
    float scaledY2 = point2.y * yScaleFactor;
    
    //** key resources
    //** see http://stackoverflow.com/questions/11523423/how-to-generate-zoom-pinch-gesture-for-testing-for-android
    //** http://developer.android.com/reference/android/view/MotionEvent.html#ACTION_POINTER_2_UP
    //** http://rogchap.com/2011/06/10/ios-image-manipulation-with-uigesturerecognizer-scale-move-rotate/
    //** http://www.codeproject.com/Articles/319401/Simple-Gestures-on-Android
    //** https://developer.apple.com/library/ios/documentation/uikit/reference/UIGestureRecognizer_Class/Reference/Reference.html#//apple_ref/c/econst/GestureRecognizerStateChanged
    //** http://stackoverflow.com/questions/10309613/find-points-of-pinch-gesture
    
    //** work through the state machine
    integer_t state = [(UIPinchGestureRecognizer*)recognizer state];
    if(state == UIGestureRecognizerStateBegan) {
        //NSLog(@"Begin PINCH TAPPED X:%f Y:%f", point1.x, point1.y);
        /*
         I/System.out( 1589): ==============
        I/System.out( 1589): PP3 0
        I/System.out( 1589): P add x:277.3828 y:146.25
        I/System.out( 1589): ==============
        I/System.out( 1589): PP1 :261
        I/System.out( 1589): P add x:277.3828 y:146.25
        I/System.out( 1589): P add x:126.5625 y:346.40625
        */
        
        //** SEND DOWN
        p = [TouchEvent_PointerCoords builder];
        eventMsg = [TouchEvent builder];
        [eventMsg setAction:0]; // android ACTION_DOWN(0)
        [p clear];
        [p setId:0];
        [p setX:scaledX1];
        [p setY:scaledY1];
        [eventMsg addItems:[p build]];
        
        
        msg = [Request builder];
        [msg setType:Request_RequestTypeTouchevent];
        [msg setTouch:[eventMsg build]];
        request = [msg build];
        [ad.client sendSVMPMessage:request];
         //NSLog(@"START ACTION DOWN %.2f ; %.2f", scaledX1, scaledY1);
        
        //** SEND DOWN
        p = [TouchEvent_PointerCoords builder];
        eventMsg = [TouchEvent builder];
        //** 1 << 8 , says that there is a second set of coordinates attached to this event
        [eventMsg setAction:5 | (1<< 8)]; // x105 = 261 android ACTION_POINTER_DOWN(5) (1 << ACTION_POINTER_INDEX_SHIFT)
        [p clear];
        [p setId:0];
        [p setX:scaledX1];
        [p setY:scaledY1];
        [eventMsg addItems:[p build]];

        [p clear];
        [p setId:1];
        [p setX:scaledX2];
        [p setY:scaledY2];
        [eventMsg addItems:[p build]];

        
        msg = [Request builder];
        [msg setType:Request_RequestTypeTouchevent];
        [msg setTouch:[eventMsg build]];
        request = [msg build];
        [ad.client sendSVMPMessage:request];
        //NSLog(@"START ACTION_POINTER_DOWN X1:%f Y1:%f X2:%f Y2:%f", scaledX1, scaledY1, scaledX2, scaledY2);
    }
    else if (state == UIGestureRecognizerStateChanged) {
        //CGFloat scale = 1.0 - (_lastScale - [(UIPinchGestureRecognizer*)recognizer scale]);
        //NSLog(@"Change scale %f", scale);
        /*
         I/System.out( 1589): ==============
        I/System.out( 1589): PP3 2
        I/System.out( 1589): P add x:212.34375 y:229.68752
        I/System.out( 1589): P add x:148.71094 y:316.875
        I/System.out( 1589): ==============
        I/System.out( 1589): PP3 2
        I/System.out( 1589): P add x:210.58594 y:237.65627
        I/System.out( 1589): P add x:156.09375 y:311.71875
        */
        
        // android ACTION_MOVE
        p = [TouchEvent_PointerCoords builder];
        eventMsg = [TouchEvent builder];
        //** 1 << 8 , says that there is a second set of coordinates attached to this event
        [eventMsg setAction:(2 | (1 << 8))]; // x102 = 258 android ACTION_MOVE(2) (1 << ACTION_POINTER_INDEX_SHIFT)

        [p clear];
        [p setId:0];
        [p setX:scaledX1];
        [p setY:scaledY1];
        [eventMsg addItems:[p build]];

        [p clear];
        [p setId: 1];
        [p setX:scaledX2];
        [p setY:scaledY2];
     
        [eventMsg addItems:[p build]];

        msg = [Request builder];
        [msg setType:Request_RequestTypeTouchevent];
        [msg setTouch:[eventMsg build]];
        request = [msg build];
        [ad.client sendSVMPMessage:request];
        //NSLog(@"Change PINCH MOVE X1:%f Y1:%f X2:%f Y2:%f", scaledX1, scaledY1, scaledX2, scaledY2);
    }
    else if (state == UIGestureRecognizerStateEnded) {
        //CGFloat scale = 1.0 - (_lastScale - [(UIPinchGestureRecognizer*)recognizer scale]);
        //NSLog(@"END scale %f", scale);
        /* I/System.out( 1589): ==============
         I/System.out( 1589): PP2 :262
         I/System.out( 1589): P add x:207.42188 y:241.87502
         I/System.out( 1589): P add x:155.74219 y:310.78125
         I/System.out( 1589): ==============
         I/System.out( 1589): PP3 1
         I/System.out( 1589): P add x:207.42188 y:241.87502
         */
        
        //NSLog(@"END PINCH X1:%f Y1:%f X2:%f Y2:%f", scaledX1, scaledY1, scaledX2, scaledY2);

        
        // android ACTION_POINTER_UP
        p = [TouchEvent_PointerCoords builder];
        eventMsg = [TouchEvent builder];
        //** 1 << 8 , says that there is a second set of coordinates attached to this event
        [eventMsg setAction:6 | (1<< 8)]; // x106 = 262 android ACTION_POINTER_UP (1 << ACTION_POINTER_INDEX_SHIFT)
        [p clear];
        [p setId:0];
        [p setX:scaledX1];
        [p setY:scaledY1];
        [eventMsg addItems:[p build]];
        [p clear];
        [p setId:1];
        [p setX:scaledX2];
        [p setY:scaledY2];
        [eventMsg addItems:[p build]];
        
        msg = [Request builder];
        [msg setType:Request_RequestTypeTouchevent];
        [msg setTouch:[eventMsg build]];
        request = [msg build];
        [ad.client sendSVMPMessage:request];
       // NSLog(@"pinch: send ACTION_POINTER_UP");
        
        //** SEND UP
        p = [TouchEvent_PointerCoords builder];
        eventMsg = [TouchEvent builder];
        [eventMsg setAction:1]; // android ACTION_UP(1)
        [p clear];
        [p setId:0];
        [p setX:scaledX1];
        [p setY:scaledY1];
        [eventMsg addItems:[p build]];
        
        msg = [Request builder];
        [msg setType:Request_RequestTypeTouchevent];
        [msg setTouch:[eventMsg build]];
        request = [msg build];
        [ad.client sendSVMPMessage:request];
        //NSLog(@"pinch: send ACTION_UP");
        
    }
    else {
        //** cancelled, failed etc
        //NSLog(@"pinch else ");
    }
    
}


- (void)sendVmRotation:(int)orientation {
    Request_Builder *msg;
    Request *request;
    
    NSLog(@"sending VM rotate - %d", orientation);
    
    APPRTCAppDelegate *ad = (APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // create a RotationInfo BuilderDr GD
    RotationInfo_Builder *riBuilder = [RotationInfo builder];
    [riBuilder setRotation: orientation];
    
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
