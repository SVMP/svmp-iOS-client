//
//  VideoView.h
//
/*
 *
 * Last updated by: Gregg Ganley
 * Nov 2013
 *
 */

#import <UIKit/UIKit.h>
#import "RTCVideoTrack.h"
#import "Svmp.pb.h"

@interface VideoView : UIView <UIGestureRecognizerDelegate>

@property (nonatomic) UIInterfaceOrientation videoOrientation;
@property (nonatomic, strong) UIImage *placeholderImage;
@property (nonatomic) BOOL isRemote;

- (void)handleTap:(UITapGestureRecognizer *)recognizer;

- (void)renderVideoTrackInterface:(RTCVideoTrack *)track;
- (void)setVideoOrientation:(UIInterfaceOrientation)videoOrientation;
- (BOOL)handleScreenInfoResponse:(Response *) msg;
- (void)cancelLoadingAndInitTouch;

- (void)pause:(id)sender;
- (void)resume:(id)sender;
- (void)stop:(id)sender;
- (UIImage*)snapshot;

@end
