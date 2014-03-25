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
 

#import "APPRTCAppDelegate.h"
#import "APViewController.h"

#import "APPRTCViewController.h"
#import "RTCICECandidate.h"
#import "RTCICEServer.h"
#import "RTCMediaConstraints.h"
#import "RTCMediaStream.h"
#import "RTCPair.h"
#import "RTCPeerConnection.h"
#import "RTCPeerConnectionDelegate.h"
#import "RTCPeerConnectionFactory.h"
#import "RTCSessionDescription.h"
#import "RTCVideoRenderer.h"
#import "RTCVideoCapturer.h"
#import "RTCVideoTrack.h"
#import "VideoView.h"

#import "Svmp.pb.h"
#import <AVFoundation/AVFoundation.h>


@interface PCObserver : NSObject<RTCPeerConnectionDelegate>

- (id)initWithDelegate:(id<APPRTCSendMessage>)delegate;
@property(nonatomic, strong)  VideoView *videoView;


@end

@implementation PCObserver {
  id<APPRTCSendMessage> _delegate;
}
@synthesize videoView = _videoView;


- (id)initWithDelegate:(id<APPRTCSendMessage>)delegate {
   NSLog(@"SEQ11- *** PeerObserver (PCO) init");

    if (self = [super init]) {
      _delegate = delegate;
   }
   return self;
}

- (void)peerConnectionOnError:(RTCPeerConnection *)peerConnection {
    NSLog(@"PCO onError.");
    NSAssert(NO, @"PeerConnection failed.");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    signalingStateChanged:(RTCSignalingState)stateChanged {
    NSLog(@"PCO onSignalingStateChange: %d", stateChanged);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
             addedStream:(RTCMediaStream *)stream {
    NSLog(@"PCO onAddStream.");
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        //** SVMP does not provide audio ...
        //NSAssert([stream.audioTracks count] >= 1,
        //         @"Expected at least 1 audio stream");

        NSAssert([stream.videoTracks count] >= 1,
                 @"Expected at least 1 video stream");
      
        if ([stream.videoTracks count] > 0) {
            [[self videoView] renderVideoTrackInterface:[stream.videoTracks objectAtIndex:0]];
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
         removedStream:(RTCMediaStream *)stream {
    NSLog(@"PCO onRemoveStream.");
    [stream removeVideoTrack:[stream.videoTracks objectAtIndex:0]];
}

- (void)
    peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {
    NSLog(@"PCO onRenegotiationNeeded.");
    // TODO(hughv): Handle this.
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate {
 
    NSLog(@"PCO onICECandidate.\n  Mid[%@] Index[%d] Sdp[%@]",
          candidate.sdpMid,
          candidate.sdpMLineIndex,
          candidate.sdp);
    NSDictionary *json =
        @{ @"type" : @"candidate",
           //3.46 change label to sdpMLineIndex @"label" : [NSNumber numberWithInt:candidate.sdpMLineIndex],
           @"sdpMLineIndex" : [NSNumber numberWithInt:candidate.sdpMLineIndex],
           //3.46 change ID to sdpMid ... @"id" : candidate.sdpMid,
           @"sdpMid" : candidate.sdpMid,
           @"candidate" : candidate.sdp };

        NSError *error;
    NSData *data =
        [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
    if (!error) {
        [_delegate sendData:data];
    } else {
        NSAssert(NO, @"Unable to serialize JSON object with error: %@",
                 error.localizedDescription);
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
        iceGatheringChanged:(RTCICEGatheringState)newState {
 
    NSLog(@"PCO onIceGatheringChange. %d", newState);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    iceConnectionChanged:(RTCICEConnectionState)newState {
    
    NSLog(@"PCO onIceConnectionChange. %d", newState);
    if (newState == RTCICEConnectionConnected)
        [self displayLogMessage:@"ICE Connection Connected."];
    NSAssert(newState != RTCICEConnectionFailed, @"ICE Connection failed!");

    //** LAST item in video setup
    if (newState == 2) {
        NSLog(@"SEQ22-*** VIDEO STREAM START !!");
        [_delegate videoStart];
    }
    
    
}

- (void)displayLogMessage:(NSString *)message {
    [_delegate displayLogMessage:message];
}

@end

@interface APPRTCAppDelegate ()

@property(nonatomic, strong) PCObserver *pcObserver;
@property(nonatomic, strong) RTCPeerConnection *peerConnection;
@property(nonatomic, strong) RTCPeerConnectionFactory *peerConnectionFactory;
@property(nonatomic, strong) NSMutableArray *queuedRemoteCandidates;

- (void) setCandidate:(NSDictionary *)objects;

@end

@implementation APPRTCAppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;
@synthesize client = _client;
@synthesize pcObserver = _pcObserver;
@synthesize peerConnection = _peerConnection;
@synthesize peerConnectionFactory = _peerConnectionFactory;
@synthesize queuedRemoteCandidates = _queuedRemoteCandidates;
@synthesize localVideoTrack = _localVideoTrack;


#pragma mark - UIApplicationDelegate methods

- (void) runNextWindow {
    ;
}

//** iMAS app passcode was successful
- (void)validUserAccess:(APViewController *)controller {
    NSLog(@"SEQ2-successful login, loading connection screen");
    [self loadFormView];
}

//** load connection page
- (void)loadFormView {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    id contID = [storyboard instantiateViewControllerWithIdentifier:@"MainViewController"];
    
    self.window.rootViewController = contID;
    [self.window makeKeyAndVisible];
}

- (void)loadRTCView {
    NSLog(@"SEQ4-Loading AppRTC video view");
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.viewController = [[APPRTCViewController alloc] initWithNibName:@"APPRTCViewController" bundle:nil];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    NSLog(@"SEQ1-Welcome to SVMP RTC Demo App!");
    [RTCPeerConnectionFactory initializeSSL];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    //** load iMAS app password view
    APViewController *apc = [[APViewController alloc] init];
    apc.delegate = self;
    self.window.rootViewController = apc;
    [self.window makeKeyAndVisible];

    return YES;
}

-(void) videoStart {
    [_viewController videoReady];
}

- (void)applicationWillResignActive:(UIApplication *)application {
  [self displayLogMessage:@"Application lost focus, connection broken."];
  [self disconnect];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

//**********************
//**********************
//**
//**
- (BOOL)launchSvmpAppClient {
    if (self.client) {
        return NO;
    }
    
    //** initialize the SVMP App Client - handles control comms
    self.client = [[APPRTCAppClient alloc] init];
    self.client.ICEServerDelegate = self;
    //self.client.messageHandler = self;

    //** send Auth Packet
    [self.client sendAuthPacket];
    return YES;
    
}

- (void)displayLogMessage:(NSString *)message {
    NSLog(@"%@", message);

}

#pragma mark - RTCSendMessage method

- (void)sendData:(NSData *)data {
  [self.client sendData:data];
}

#pragma mark - ICEServerDelegate method

//**********************
//**********************
//**
//** Setup VIDEO and AUDIO streams here
//**
- (void)onICEServers:(NSArray *)servers {
    
    //** may need this in the future
    //RTCICEServer *server = [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:@"turn:127.0.0.1:3478"] username:@"username" password:@"password"];
    
    //** SVMP turn off AUDIO in offer
    RTCMediaConstraints *_constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@[[[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"false"], [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"true"]] optionalConstraints:@[[[RTCPair alloc] initWithKey:@"internalSctpDataChannels" value:@"true"], [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]]];

    
    self.queuedRemoteCandidates = [NSMutableArray array];
    self.peerConnectionFactory = [[RTCPeerConnectionFactory alloc] init];
    self.pcObserver = [[PCObserver alloc] initWithDelegate:self];
    self.peerConnection =
      [self.peerConnectionFactory peerConnectionWithICEServers:servers
                                                   constraints:_constraints
                                                      delegate:self.pcObserver];
    RTCMediaStream *lms =
      [self.peerConnectionFactory mediaStreamWithLabel:@"ARDAMS"];
    NSLog(@"SEQ12-Adding Audio and Video devices ...");
    //** SVMP remove audio track
    //[lms addAudioTrack:[self.peerConnectionFactory audioTrackWithID:@"ARDAMSa0"]];
    
  
    //**  http://code.google.com/p/webrtc/issues/detail?id=2246
  
    //** pass the videoView to the observer, for later rendering
    self.pcObserver.videoView = self.viewController.videoView;

    //** add stream
    [self.peerConnection addStream:lms constraints:_constraints];


    //[self displayLogMessage:@"onICEServers - add local stream."];
    //NSLog(@"Adding Audio and Video devices ... DONE");
    
    //** create offer
    [self onOpen];
}

#pragma mark - GAEMessageHandler methods

//**********************
//**********************
//**
//**
- (void)onOpen {
    [self displayLogMessage:@"GAE onOpen - create offer."];
    
    //** SVMP audio to false
    RTCPair *audio = [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"false"];
    
    //** video added
    RTCPair *video = [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"true"];
    NSArray *mandatory = @[ audio , video ];

    RTCMediaConstraints *constraints =
      [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatory
                                            optionalConstraints:nil];
    [self displayLogMessage:@"SEQ13-PC - createOffer."];
    [self.peerConnection createOfferWithDelegate:self constraints:constraints];

}

//**********************
//**********************
//**
//**
//** SVMP, candidates
- (void) setCandidate:(NSDictionary *)objects {
    NSLog(@"SEQ21-SET GAE CANDIDATE");
    
    NSString *mid = [objects objectForKey:@"sdpMid"];
    NSNumber *sdpLineIndex = [objects objectForKey:@"sdpMLineIndex"];
    NSString *sdp = [objects objectForKey:@"candidate"];
        
    //** alloc a candidate object, add to ICE candidate list
    RTCICECandidate *candidate =
    [[RTCICECandidate alloc] initWithMid:mid
                                   index:sdpLineIndex.intValue
                                     sdp:sdp];
    
    NSLog(@"adding candidates! %@", candidate);
    
    if (self.queuedRemoteCandidates) {
        NSLog(@"adding queuedRemoteCandidates");
        [self.queuedRemoteCandidates addObject:candidate];
    } else {
        NSLog(@"adding ICE peerConnection");
        [self.peerConnection addICECandidate:candidate];
    }
}

//**********************
//**********************
//**
//**
//** SVMP, change parameter to SVMP response from NString
- (void)onMessage:(Response *) resp {
 
    [self displayLogMessage:@"*** HERE in onMessage"];
    
    //NSData *data = [msg dataUsingEncoding:NSUTF8StringEncoding];
    //Response *resp = [Response parseFromData:data];
    Response_ResponseType rt = [resp type];

    switch ( rt ) {
      case Response_ResponseTypeAuth:
        {
          NSLog(@"Response_ResponseTypeAuth received");
          break;
        }
      case Response_ResponseTypeScreeninfo:
        {
          NSLog(@"Response_ResponseScreeninfo received");
          break;
        }
      case Response_ResponseTypeLocation:
        {
          NSLog(@"Response_ResponseTypeLocation received");
          //handleLocationResponse(data);
          break;
        }
      // This is an ACK to the video STOP request.
      case Response_ResponseTypeIntent:
      case Response_ResponseTypeNotification:
        {
          NSLog(@"Response_ResponseTypeNotification or INTENT");
          //Inspect this message to see if it's an intent or notification.
          //NetIntentsHandler.inspect(data, AppRTCDemoActivity.this);
          break;
        }
      case Response_ResponseTypeWebrtc:
        {
          NSLog(@"Response_ResponseTypeWebrtc");

          //** remove % and & etc
          NSString *message = [[resp webrtcMsg] json];
          NSError *error;

          //** Convert json into NSDictionary
          NSDictionary *objects = [NSJSONSerialization
            JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding]
                         options:0 error:&error];
          NSAssert(!error, @"%@",
                   [NSString stringWithFormat:@"Error: %@", error.description]);
          NSAssert([objects count] > 0, @"Invalid JSON object");
            
          //** get the message type value
          NSString *value = [objects objectForKey:@"type"];
          NSLog(@"GAE onMessage type - %@", value);

          //** CANDIDATE
          if ([value compare:@"candidate"] == NSOrderedSame) {
            NSLog(@"GAE CANDIDATE");
              
            //NSString *mid = [objects objectForKey:@"id"];
            NSString *mid = [objects objectForKey:@"sdpMid"];
              
            //NSNumber *sdpLineIndex = [objects objectForKey:@"label"];
            NSNumber *sdpLineIndex = [objects objectForKey:@"sdpMLineIndex"];
            NSString *sdp = [objects objectForKey:@"candidate"];

            //** alloc a candidate object, add to ICE candidate list
            RTCICECandidate *candidate =
                [[RTCICECandidate alloc] initWithMid:mid
                                               index:sdpLineIndex.intValue
                                                 sdp:sdp];
            if (self.queuedRemoteCandidates) {
              [self.queuedRemoteCandidates addObject:candidate];
            } else {
              [self.peerConnection addICECandidate:candidate];
            }
              
          //** OFFER and ANSWER
          } else if (([value compare:@"offer"] == NSOrderedSame) ||
                     ([value compare:@"answer"] == NSOrderedSame)) {
            NSLog(@"SEQ-20 OFFER and ANSWER");
              
            NSString *sdpString = [objects objectForKey:@"sdp"];
            RTCSessionDescription *sdp = [[RTCSessionDescription alloc]
                initWithType:value sdp:[APPRTCAppDelegate preferISAC:sdpString]];
            [self.peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:sdp];
            //[self displayLogMessage:@"PC - setRemoteDescription."];

          //** BYE
          } else if ([value compare:@"bye"] == NSOrderedSame) {
              NSLog(@"BYE");
              [self disconnect];

          //** GARBAGE
          } else {
            NSAssert(NO, @"Invalid message: %@", resp);
          }

          break;
        }
        default:
            NSLog(@"Unexpected protocol message of type %d", rt);
    }
    

    
}

//**
//** client side video shutdown
- (void)onClose {
    [self displayLogMessage:@"GAE onClose."];
    [self disconnect];
    exit(0);
}

//** onError with retrys
int cnt = 0;
- (void)onError:(int)code withDescription:(NSString *)description {
  [self displayLogMessage:
          [NSString stringWithFormat:@"GAE onError %d:  %@", cnt, description]];
  NSLog(@"XXXXX onERROR ...");
    
  if (++cnt > 1) {
    //** allow for a retry, not sure if this works
    NSLog(@"XXXXX onERROR CNT > 1 disconnecting ...");
    [self disconnect];
  }
}


#pragma mark - RTCSessionDescriptonDelegate methods

//**********************
//**********************
//**
//**
// Match |pattern| to |string| and return the first group of the first
// match, or nil if no match was found.
+ (NSString *)firstMatch:(NSRegularExpression *)pattern
              withString:(NSString *)string {
  
    NSTextCheckingResult* result =
    [pattern firstMatchInString:string
                        options:0
                          range:NSMakeRange(0, [string length])];
    if (!result)
        return nil;

    return [string substringWithRange:[result rangeAtIndex:1]];
}

//**********************
//**********************
//**
//**
// Mangle |origSDP| to prefer the ISAC/16k audio codec.
+ (NSString *)preferISAC:(NSString *)origSDP {
  int mLineIndex = -1;
  NSString* isac16kRtpMap = nil;
  NSArray* lines = [origSDP componentsSeparatedByString:@"\n"];
  NSRegularExpression* isac16kRegex = [NSRegularExpression
      regularExpressionWithPattern:@"^a=rtpmap:(\\d+) ISAC/16000[\r]?$"
                           options:0
                             error:nil];
  for (int i = 0;
       (i < [lines count]) && (mLineIndex == -1 || isac16kRtpMap == nil);
       ++i) {
    NSString* line = [lines objectAtIndex:i];
    if ([line hasPrefix:@"m=audio "]) {
      mLineIndex = i;
      continue;
    }
    isac16kRtpMap = [self firstMatch:isac16kRegex withString:line];
  }
  if (mLineIndex == -1) {
    NSLog(@"No m=audio line, so can't prefer iSAC");
    return origSDP;
  }
  if (isac16kRtpMap == nil) {
    NSLog(@"No ISAC/16000 line, so can't prefer iSAC");
    return origSDP;
  }
  NSArray* origMLineParts =
      [[lines objectAtIndex:mLineIndex] componentsSeparatedByString:@" "];
  NSMutableArray* newMLine =
      [NSMutableArray arrayWithCapacity:[origMLineParts count]];
  int origPartIndex = 0;
  // Format is: m=<media> <port> <proto> <fmt> ...
  [newMLine addObject:[origMLineParts objectAtIndex:origPartIndex++]];
  [newMLine addObject:[origMLineParts objectAtIndex:origPartIndex++]];
  [newMLine addObject:[origMLineParts objectAtIndex:origPartIndex++]];
  [newMLine addObject:isac16kRtpMap];
  for (; origPartIndex < [origMLineParts count]; ++origPartIndex) {
    if ([isac16kRtpMap compare:[origMLineParts objectAtIndex:origPartIndex]]
        != NSOrderedSame) {
      [newMLine addObject:[origMLineParts objectAtIndex:origPartIndex]];
    }
  }
  NSMutableArray* newLines = [NSMutableArray arrayWithCapacity:[lines count]];
  [newLines addObjectsFromArray:lines];
  [newLines replaceObjectAtIndex:mLineIndex
                      withObject:[newMLine componentsJoinedByString:@" "]];
  return [newLines componentsJoinedByString:@"\n"];
}


//**********************
//**********************
//**
//**
- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didCreateSessionDescription:(RTCSessionDescription *)origSdp
                          error:(NSError *)error {
  if (error) {
    [self displayLogMessage:@"SDP onFailure."];
    NSAssert(NO, error.description);
    return;
  }

  [self displayLogMessage:@"SEQ14-SDP onSuccess(SDP) - set local description. GG"];
  RTCSessionDescription* sdp =
      [[RTCSessionDescription alloc]
          initWithType:origSdp.type
                   sdp:[APPRTCAppDelegate preferISAC:origSdp.description]];
    
  [self displayLogMessage:@"SEQ15-PC setLocalDescription."];
  [self.peerConnection setLocalDescriptionWithDelegate:self
                                    sessionDescription:sdp];
  dispatch_async(dispatch_get_main_queue(), ^(void) {
    NSDictionary *json = @{ @"type" : sdp.type, @"sdp" : sdp.description };
    NSError *error;
    NSData *data =
        [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
    NSAssert(!error,
             @"%@",
             [NSString stringWithFormat:@"Error: %@", error.description]);
      
    [self sendData:data];
  });
}

//**********************
//**********************
//**
//**
- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didSetSessionDescriptionWithError:(NSError *)error {
  if (error) {
    [self displayLogMessage:@"SDP onFailure."];
    NSAssert(NO, error.description);
    return;
  }

  [self displayLogMessage:@"SDP onSuccess() - possibly drain candidates"];
  dispatch_async(dispatch_get_main_queue(), ^(void) {
    // TODO(hughv): Handle non-initiator case.  http://s10/46622051
    if (self.peerConnection.remoteDescription) {
      [self displayLogMessage:@"SDP onSuccess - drain candidates"];
      [self drainRemoteCandidates];
    } else {
        NSLog(@"*** self.peerConnection.remoteDescription is NULL");
    }
  });
}

#pragma mark - internal methods

//**********************
//**********************
//**
//**
- (void)disconnect {
  [self.client
      sendData:[@"{\"type\": \"bye\"}" dataUsingEncoding:NSUTF8StringEncoding]];
  self.peerConnection = nil;
  self.peerConnectionFactory = nil;
  self.pcObserver = nil;
  self.client.ICEServerDelegate = nil;
  //self.client.messageHandler = nil;
  self.client = nil;
  [RTCPeerConnectionFactory deinitializeSSL];
}

//**********************
//**********************
//**
//**
- (void)drainRemoteCandidates {
  for (RTCICECandidate *candidate in self.queuedRemoteCandidates) {
    [self.peerConnection addICECandidate:candidate];
  }
  self.queuedRemoteCandidates = nil;
}

//**********************
//**********************
//**
//**
- (NSString *)unHTMLifyString:(NSString *)base {
  // TODO(hughv): Investigate why percent escapes are being added.  Removing
  // them isn't necessary on Android.
  // convert HTML escaped characters to UTF8.
  NSString *removePercent =
      [base stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
  // remove leading and trailing ".
  NSRange range;
  range.length = [removePercent length] - 2;
  range.location = 1;
  NSString *removeQuotes = [removePercent substringWithRange:range];
  // convert \" to ".
  NSString *removeEscapedQuotes =
      [removeQuotes stringByReplacingOccurrencesOfString:@"\\\""
                                              withString:@"\""];
  // convert \\ to \.
  NSString *removeBackslash =
      [removeEscapedQuotes stringByReplacingOccurrencesOfString:@"\\\\"
                                                     withString:@"\\"];
  return removeBackslash;
}

@end
