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

#import "APPRTCAppClient.h"
#import "APPRTCAppDelegate.h"
#import "APPRTCViewController.h"
#import <dispatch/dispatch.h>
#import <SecureFoundation/SecureFoundation.h>
#import "GAEChannelClient.h"
#import "RTCICEServer.h"

@interface APPRTCAppClient ()

@property(nonatomic) dispatch_queue_t backgroundQueue;
@property(nonatomic, copy) NSString *baseURL;
@property(nonatomic, strong) GAEChannelClient *gaeChannel;
@property(nonatomic, copy) NSString *postMessageUrl;
@property(nonatomic, copy) NSString *pcConfig;
@property(nonatomic, strong) NSMutableString *roomHtml;
@property(atomic, strong) NSMutableArray *sendQueue;
@property(nonatomic, copy) NSString *token;

@property(nonatomic, assign) BOOL verboseLogging;

@end

@implementation APPRTCAppClient

@synthesize ICEServerDelegate = _ICEServerDelegate;
@synthesize messageHandler = _messageHandler;

@synthesize backgroundQueue = _backgroundQueue;
@synthesize baseURL = _baseURL;
@synthesize gaeChannel = _gaeChannel;
@synthesize postMessageUrl = _postMessageUrl;
@synthesize pcConfig = _pcConfig;
@synthesize roomHtml = _roomHtml;
@synthesize sendQueue = _sendQueue;
@synthesize token = _token;
@synthesize verboseLogging = _verboseLogging;
//@synthesize appDelegate = _appDelegate;

//** SVMP
@synthesize inputStream, outputStream;
@synthesize inputBuffer;

int cnt;

//*****************
//*****************
- (id)init {
  if (self = [super init]) {
    _backgroundQueue = dispatch_queue_create("RTCBackgroundQueue", NULL);
    _sendQueue = [NSMutableArray array];
    // Uncomment to see Request/Response logging.
    _verboseLogging = YES;
   [self initSVMPCommunication];
   cnt = 0;
      
    //_appDelegate = (APPRTCAppDelegate *) [[UIApplication sharedApplication] delegate];
  }
  return self;
}

#pragma mark - Public methods

//*****************
//*****************
- (void)connectToRoom:(NSURL *)url {
  //NSURLRequest *request = [self getRequestFromUrl:url];
  //[NSURLConnection connectionWithRequest:request delegate:self];

  //** connect to SVMP server
  [self sendAuthPacket];
}

//*****************
//*****************
- (void)sendData:(NSData *)data {
    NSLog(@"*** HERE in sendData 000");
    
    
    //** SVMP wrap
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //msg = [msg stringByReplacingOccurrencesOfString:@"\\r\\n"  withString:@"\\n"];
    //msg = [msg stringByReplacingOccurrencesOfString:@"\\n"  withString:@"\\\\n"];
    WebRTCMessage_Builder *rtcBuild = [WebRTCMessage builder];
    [rtcBuild setJson:msg];
    WebRTCMessage *rtcmsg = [rtcBuild build];

    Request_Builder *rBuild = [Request builder];
    [rBuild setType:Request_RequestTypeWebrtc];
    [rBuild setWebrtcMsg:rtcmsg];
    Request *request = [rBuild build];
    //NSData  *rdata = [request data];

    /*
    WebRTCMessage.Builder rtcmsg = WebRTCMessage.newBuilder();
    rtcmsg.setJson(msg);
    
    sendMessage(Request.newBuilder()
                .setType(RequestType.WEBRTC)
                .setWebrtcMsg(rtcmsg)
                .build());
    */
    
  @synchronized(self) {
    [self maybeLogMessage:@"Send message - Add to sendQ"];
    [self.sendQueue addObject:request];
  }
  [self requestQueueDrainInBackground];
}

#pragma mark - Internal methods


//*****************
//*****************
- (NSString*)findVar:(NSString*)name
     strippingQuotes:(BOOL)strippingQuotes {
  NSError* error;
  NSString* pattern =
      [NSString stringWithFormat:@".*\n *var %@ = ([^\n]*);\n.*", name];
  NSRegularExpression *regexp =
      [NSRegularExpression regularExpressionWithPattern:pattern
                                                options:0
                                                  error:&error];
  NSAssert(!error, @"Unexpected error compiling regex: ",
           error.localizedDescription);

  NSRange fullRange = NSMakeRange(0, [self.roomHtml length]);
  NSArray *matches =
      [regexp matchesInString:self.roomHtml options:0 range:fullRange];
  if ([matches count] != 1) {
    [self showMessage:[NSString stringWithFormat:@"%d matches for %@ in %@",
                                [matches count], name, self.roomHtml]];
    return nil;
  }
  NSRange matchRange = [matches[0] rangeAtIndex:1];
  NSString* value = [self.roomHtml substringWithRange:matchRange];
  if (strippingQuotes) {
    NSAssert([value length] > 2,
             @"Can't strip quotes from short string: [%@]", value);
    NSAssert(([value characterAtIndex:0] == '\'' &&
              [value characterAtIndex:[value length] - 1] == '\''),
             @"Can't strip quotes from unquoted string: [%@]", value);
    value = [value substringWithRange:NSMakeRange(1, [value length] - 2)];
  }
  return value;
}

//*****************
//*****************
- (NSURLRequest *)getRequestFromUrl:(NSURL *)url {
  self.roomHtml = [NSMutableString stringWithCapacity:20000];
  NSString *path =
      [NSString stringWithFormat:@"https:%@", [url resourceSpecifier]];
  NSURLRequest *request =
      [NSURLRequest requestWithURL:[NSURL URLWithString:path]];
  return request;
}


//*****************
//*****************
- (void)maybeLogMessage:(NSString *)message {
  if (self.verboseLogging) {
    NSLog(@"%@", message);
  }
}


//*****************
//*****************
- (void)requestQueueDrainInBackground {
  NSLog(@"*** HERE in requestQueueDrainInBackground");
  dispatch_async(self.backgroundQueue, ^(void) {
    // TODO(hughv): This can block the UI thread.  Fix.
    @synchronized(self) {
      NSLog(@"*** HERE in SYNC of requestQueueDrainInBackground");
        
      /*if ([self.postMessageUrl length] < 1) {
        return;
      }*/

      Request *req;
      for (req in self.sendQueue) {
          [self sendSVMPMessage:req];
       /*NSString *url = [NSString stringWithFormat:@"%@/%@",
                         self.baseURL,
                         self.postMessageUrl];
        [self sendData:data withUrl:url]; 
       */
      }
      

      [self.sendQueue removeAllObjects];
    }
  });
}


//*****************
//*****************
- (void)sendData:(NSData *)data withUrl:(NSString *)url {
  NSLog(@"*** HERE in sendData 111");
    
  NSMutableURLRequest *request =
      [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
  request.HTTPMethod = @"POST";
  [request setHTTPBody:data];
  //** SEND
  NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  NSLog(@"*** POST DATA %@", str);

    
  NSURLResponse *response;
  NSError *error;
  NSData *responseData = [NSURLConnection sendSynchronousRequest:request
                                               returningResponse:&response
                                                           error:&error];
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  int status = [httpResponse statusCode];
  NSLog(@"*** RESPONSE status %i", status);
  NSLog(@"*** RESPONSE error %@", error);
  NSString *rd = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
  NSLog(@"*** RESPONSE responseData %@", rd);
  NSAssert(status == 200,
           @"Bad response [%d] to message: %@\n\n%@",
           status,
           [NSString stringWithUTF8String:[data bytes]],
           [NSString stringWithUTF8String:[responseData bytes]]);
}

//*****************
//*****************
- (void)showMessage:(NSString *)message {
  NSLog(@"%@", message);
  UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Unable to join"
                                                      message:message
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
  [alertView show];
}

//*****************
//*****************
- (void)updateICEServers:(NSMutableArray *)ICEServers
          withTurnServer:(NSString *)turnServerUrl {
    
  if ([turnServerUrl length] < 1) {
    [self.ICEServerDelegate onICEServers:ICEServers];
    return;
  }

  dispatch_async(self.backgroundQueue, ^(void) {

/* SVMP turn off this send, we already have the turnserver
     NSMutableURLRequest *request = [NSMutableURLRequest
        requestWithURL:[NSURL URLWithString:turnServerUrl]];
    [request addValue:@"Mozilla/5.0" forHTTPHeaderField:@"user-agent"];
    [request addValue:@"https://apprtc.appspot.com"
        forHTTPHeaderField:@"origin"];
    NSURLResponse *response;
    NSError *error;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request
                                                 returningResponse:&response
                                                             error:&error];
    if (!error) {
      NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData
                                                           options:0
                                                             error:&error];
      NSAssert(!error, @"Unable to parse.  %@", error.localizedDescription);
      NSString *username = json[@"username"];
      NSString *password = json[@"password"];
      NSArray* uris = json[@"uris"];
      for (int i = 0; i < [uris count]; ++i) {
        NSString *turnServer = [uris objectAtIndex:i];
        RTCICEServer *ICEServer =
          [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:turnServer]
                                   username:username
                                   password:password];
        NSLog(@"Added ICE Server: %@", ICEServer);
        [ICEServers addObject:ICEServer];
      }
    } else {
      NSLog(@"Unable to get TURN server.  Error: %@", error.description);
    }
 */

    dispatch_async(dispatch_get_main_queue(), ^(void) {
      [self.ICEServerDelegate onICEServers:ICEServers];
    });
  });
}

#pragma mark - NSURLConnectionDataDelegate methods

//*****************
//*****************
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    //** NSURL response handler #1
    NSString *roomHtml = [NSString stringWithUTF8String:[data bytes]];
    [self maybeLogMessage:
            [NSString stringWithFormat:@"Received %d chars", [roomHtml length]]];
    [self.roomHtml appendString:roomHtml];
}

//*****************
//*****************
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    //** NSURL response handler #2
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    int statusCode = [httpResponse statusCode];
    [self maybeLogMessage:
          [NSString stringWithFormat:
                  @"Response received\nURL\n%@\nStatus [%d]\nHeaders\n%@",
              [httpResponse URL],
              statusCode,
              [httpResponse allHeaderFields]]];
    NSAssert(statusCode == 200, @"Invalid response  of %d received.", statusCode);
}


//** Added this code to fix issue with test SSL server cert not working properly.
//** 
//-(void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
        //if ([trustedHosts containsObject:challenge.protectionSpace.host])
    [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}
//**
//**

//*****************
//*****************
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  //** NSURL response handler #3
    
  [self maybeLogMessage:[NSString stringWithFormat:@"finished loading %d chars",
                         [self.roomHtml length]]];
/*   NSRegularExpression* fullRegex =
    [NSRegularExpression regularExpressionWithPattern:@"room is full"
                                              options:0
                                                error:nil];
  if ([fullRegex
          numberOfMatchesInString:self.roomHtml
                          options:0
                            range:NSMakeRange(0, [self.roomHtml length])]) {
    [self showMessage:@"Room full"];
    return;
  }
*/
    
  NSString *fullUrl = [[[connection originalRequest] URL] absoluteString];
  NSRange queryRange = [fullUrl rangeOfString:@"?"];
  self.baseURL = [fullUrl substringToIndex:queryRange.location];
  [self maybeLogMessage:
      [NSString stringWithFormat:@"Base URL: %@", self.baseURL]];

  self.token = [self findVar:@"channelToken" strippingQuotes:YES];
  if (!self.token)
    return;
  [self maybeLogMessage:[NSString stringWithFormat:@"Token: %@", self.token]];

  NSString* roomKey = [self findVar:@"roomKey" strippingQuotes:YES];
  NSString* me = [self findVar:@"me" strippingQuotes:YES];
  if (!roomKey || !me)
    return;
  self.postMessageUrl =
    [NSString stringWithFormat:@"/message?r=%@&u=%@", roomKey, me];
  [self maybeLogMessage:[NSString stringWithFormat:@"POST message URL: %@",
                                  self.postMessageUrl]];

  NSString* pcConfig = [self findVar:@"pcConfig" strippingQuotes:NO];
  if (!pcConfig)
    return;
  [self maybeLogMessage:
          [NSString stringWithFormat:@"PC Config JSON: %@", pcConfig]];

  NSString *turnServerUrl = [self findVar:@"turnUrl" strippingQuotes:YES];
  if (turnServerUrl) {
    [self maybeLogMessage:
            [NSString stringWithFormat:@"TURN server request URL: %@",
                turnServerUrl]];
  }

  NSError *error;
  NSData *pcData = [pcConfig dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *json =
      [NSJSONSerialization JSONObjectWithData:pcData options:0 error:&error];
  NSAssert(!error, @"Unable to parse.  %@", error.localizedDescription);
  NSArray *servers = [json objectForKey:@"iceServers"];
  NSMutableArray *ICEServers = [NSMutableArray array];
  for (NSDictionary *server in servers) {
    NSString *url = [server objectForKey:@"url"];
    NSString *username = json[@"username"];
    NSString *credential = [server objectForKey:@"credential"];
    if (!username) {
      username = @"";
    }
    if (!credential) {
      credential = @"";
    }
    [self maybeLogMessage:
            [NSString stringWithFormat:@"url [%@] - credential [%@]",
                url,
                credential]];
    RTCICEServer *ICEServer =
        [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:url]
                                 username:username
                                 password:credential];
    NSLog(@"Added ICE Server: %@", ICEServer);
    [ICEServers addObject:ICEServer];
  }
  [self updateICEServers:ICEServers withTurnServer:turnServerUrl];

  [self maybeLogMessage:
          [NSString stringWithFormat:@"About to open GAE with token:  %@",
              self.token]];
  self.gaeChannel =
      [[GAEChannelClient alloc] initWithToken:self.token
                                     delegate:self.messageHandler];
}


//*****************
//*****************
- (void)processSVMPVideoParams:(Response *)resp {
    //** processing room params
    
    NSLog(@"vid params: %@", [resp videoInfo]);

/*
    NSString *fullUrl = [[[connection originalRequest] URL] absoluteString];
    NSRange queryRange = [fullUrl rangeOfString:@"?"];
    self.baseURL = [fullUrl substringToIndex:queryRange.location];
    [self maybeLogMessage:
     [NSString stringWithFormat:@"Base URL: %@", self.baseURL]];
    
    self.token = [self findVar:@"channelToken" strippingQuotes:YES];
    if (!self.token)
        return;
    [self maybeLogMessage:[NSString stringWithFormat:@"Token: %@", self.token]];
    
    NSString* roomKey = [self findVar:@"roomKey" strippingQuotes:YES];
    NSString* me = [self findVar:@"me" strippingQuotes:YES];
    if (!roomKey || !me)
        return;
    self.postMessageUrl =
    [NSString stringWithFormat:@"/message?r=%@&u=%@", roomKey, me];
    [self maybeLogMessage:[NSString stringWithFormat:@"POST message URL: %@",
                           self.postMessageUrl]];
*/
    
    //** pcConfig
    NSString* pcConfig = [[resp videoInfo] pcConstraints]; //[self findVar:@"pcConfig" strippingQuotes:NO];
    if (!pcConfig)
        return;
    [self maybeLogMessage:
     [NSString stringWithFormat:@"PC Config JSON: %@", pcConfig]];
    
    //** turn server
    NSString *turnServerUrl = [[resp videoInfo] iceServers];
    if (turnServerUrl) {
        [self maybeLogMessage:
         [NSString stringWithFormat:@"TURN server request URL: %@",
          turnServerUrl]];
    }
    
    NSError *error;
    //NSData *pcData = [pcConfig dataUsingEncoding:NSUTF8StringEncoding];
    NSData *turnServerUrlData = [turnServerUrl dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json =
        [NSJSONSerialization JSONObjectWithData:turnServerUrlData options:0 error:&error];
    NSAssert(!error, @"Unable to parse.  %@", error.localizedDescription);

    NSArray *servers = [json objectForKey:@"iceServers"];
    NSMutableArray *ICEServers = [NSMutableArray array];
    for (NSDictionary *server in servers) {
        NSString *url = [server objectForKey:@"url"];
        NSString *username = @"gganley"; //json[@"username"];
        NSString *credential = @""; //[server objectForKey:@"credential"];
        if (!username) {
            username = @"";
        }
        if (!credential) {
            credential = @"";
        }
        [self maybeLogMessage:
            [NSString stringWithFormat:@"url [%@] - credential [%@]",
             url,
             credential]];
        
        RTCICEServer *ICEServer =
        [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:url]
                                 username:username
                                 password:credential];
        NSLog(@"Added ICE Server: %@", ICEServer);
        [ICEServers addObject:ICEServer];
    }
    [self updateICEServers:ICEServers withTurnServer:turnServerUrl];
    
    [self maybeLogMessage:
     [NSString stringWithFormat:@"About to open GAE with token:  %@",  self.token]];
    
    self.gaeChannel =
    [[GAEChannelClient alloc] initWithToken:self.token
                                   delegate:self.messageHandler];
    
    //** create offer
    // [(APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate] onOpen];
}




//******************
//******************
//**
//**
- (void) initSVMPCommunication {
	
	CFReadStreamRef readStream;
	CFWriteStreamRef writeStream;
    
    NSData* hostData = [IMSKeychain securePasswordDataForService:@"host" account:@"1"];
    NSString * hostStr = [[NSString alloc] initWithData:hostData encoding:NSUTF8StringEncoding];
    NSData* portData = [IMSKeychain securePasswordDataForService:@"port" account:@"1"];
    NSString * portStr = [[NSString alloc] initWithData:portData encoding:NSUTF8StringEncoding];
    
    
    //** IP address of the PROXY SERVER
	CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)hostStr, [portStr integerValue], &readStream, &writeStream);
	
	inputStream = (NSInputStream *)CFBridgingRelease(readStream);
	outputStream = (NSOutputStream *)CFBridgingRelease(writeStream);
	[inputStream setDelegate:self];
	[outputStream setDelegate:self];
	[inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[inputStream open];
	[outputStream open];
	
}



//** connect to room
- (void)sendAuthPacket {
    
    AuthRequest_Builder* authData = [AuthRequest builder];
    [authData setType:AuthRequest_AuthRequestTypeAuthentication];
    [authData setUsername:@"gganley"];
    [authData setPassword:@"g"];
    //** leave sessionToken blank, server will provide one
    // [authData setSessionToken:@""];
    AuthRequest* ar = [authData build];
    
    
    Request_Builder* rBuild = [Request builder];
    [rBuild setType:Request_RequestTypeAuth];
    [rBuild setAuthRequest:ar];
    
    Request* request = [rBuild build];
    
    [self sendSVMPMessage:request];
}


- (void) writeLenToStream:(PBCodedOutputStream *)os length:(uint16_t)len {

    NSLog(@"length: %d", len);
    //** break up lenght into two bytes to be added to front of packet, since Java does not deal well with unsigned numbers, need to encode
    //** data into bytes this way.  Took many hours to figure out this byte stuffing technique
    uint8_t h = (len >>7) & 0xff;
    uint8_t l = (len & 0xff);
    //** hack!
    if (len < 860 && len > 840)
      l |= 0x80;
    NSLog(@"h:%02X l:%02X", h,l);
    
    //** prepend it to message, such that Request.parseDelimitedFrom(in) can parse it properly
    [os writeRawByte:l];
    if (len > 127) {
        //** java side expects the packet to be led with a length
        [os writeRawByte:h];
        //[os writeRawByte:0xff];
        //[os writeRawByte:0];
    }

    
    
}


/*
- (uint16_t) readLenFromInt:(int)input {
    
    NSLog(@"length: %d", input);
    //** break up lenght into two bytes to be added to front of packet, since Java does not deal well with unsigned numbers, need to encode
    //** data into bytes this way.  Took many hours to figure out this byte stuffing technique
    uint8_t h = (len >>7) & 0xff;
    uint8_t l = (len & 0xff);
    NSLog(@"h:%02X l:%02X", h,l);
    
    //** prepend it to message, such that Request.parseDelimitedFrom(in) can parse it properly
    [os writeRawByte:l];
    if (len > 127) {
        //** java side expects the packet to be led with a 32 bit length number
        [os writeRawByte:h];
        //[os writeRawByte:0xff];
        //[os writeRawByte:0];
    }

}
*/

- (void)sendSVMPMessage:(Request *) request {


    //** get length
    NSData* n = [request data];
    NSLog(@"sendSVMPMessage type:%u", [request type]);
    NSLog(@"sendSVMPMessage Request:%@", request);
    
/*
    uint16_t len = [n length];
    
    NSLog(@"length: %d", len);
    //** break up lenght into two bytes to be added to front of packet, since Java does not deal well with unsigned numbers, need to encode
    //** data into bytes this way.  Took many hours to figure out this byte stuffing technique
    uint8_t h = (len >>7) & 0xff;
    uint8_t l = (len & 0xff);
    NSLog(@"h:%02X l:%02X", h,l);
*/
 
    PBCodedOutputStream* os = [PBCodedOutputStream streamWithOutputStream:outputStream];
    
/*    //** prepend it to message, such that Request.parseDelimitedFrom(in) can parse it properly
    [os writeRawByte:l];
    if (len > 127) {
        //** java side expects the packet to be led with a 32 bit length number
        [os writeRawByte:h];
        //[os writeRawByte:0xff];
        //[os writeRawByte:0];
    }
 */
    [self writeLenToStream:os length:[n length]];
    [request writeToCodedOutputStream:os];
    [os flush];
}


//*****************
//*****************
//**
//**
- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    
    //NSLog(@"stream event %i", streamEvent);
	
	switch (streamEvent) {
			
		case NSStreamEventOpenCompleted:
		{
            NSLog(@"Stream opened");
			break;
		}
        case NSStreamEventHasBytesAvailable:
        {
            //NSLog(@" INPUT Stream NSStreamEventHasBytesAvailable");
            if (theStream == inputStream) {
				uint8_t buffer[2048];
				int len;
                //PBCodedInputStream* is = [PBCodedInputStream streamWithInputStream:inputStream];
                //len = [inputStream read:&abuf maxLength:1];
                //[self messageReceived:is];
                while ([inputStream hasBytesAvailable]) {

					len = [inputStream read:buffer maxLength:sizeof(buffer)];
					if (len > 0) {
                        //** get length of recieved buffer
                        int plen = buffer[0];
                        NSLog(@"len: %i %i", len, plen);
                        int offset = 1;
                        if (len - plen > 1) {
                            offset = 2;
                        }
                        len = len - offset;
                        
                        //** advance the buffer pointer passed the first byte and shorten the length by 1
                        //** copy into object and keep a handle to it.
                        inputBuffer = [NSData dataWithBytes:(buffer + offset) length:len];
                        int t = [inputBuffer length];
                        NSLog(@"input buffer len: %d", t);
                        //NSData *dataData = [NSData dataWithBytes:buffer length:sizeof(buffer)];
                       // NSLog(@"buf ...%@...", dataData);
                         //NSString *str = [[NSString alloc] initWithData:inputBuffer encoding:NSUTF8StringEncoding];
                         //NSLog(@"msgIN - %@",str);
						[self messageReceived:inputBuffer length:len];
 
                    }
                }
            }
			break;
        }
		case NSStreamEventHasSpaceAvailable:
        {
			NSLog(@"NSStreamEventHasSpaceAvailable");
            //[outputStream write:0 maxLength:1]; //[msg length]];
            //NSString *response  = [NSString stringWithFormat:@"foobar"];
            //NSData *data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSASCIIStringEncoding]];
            //[outputStream write:[data bytes] maxLength:[data length]]; //[msg length]];
			break;
		}
        case NSStreamEventErrorOccurred:
		{
			NSLog(@"Cannot connect to the host!");
			break;
		}
		case NSStreamEventEndEncountered:
        {
            NSLog(@"NSStreamEventEndEncountered!");
            [theStream close];
            [theStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            //[theStream release];
            theStream = nil;
			break;
        }
		default:
			NSLog(@"Unknown event");
	}
    
}

//int cnt = 0;
//*****************
//*****************
//**
//**
- (void) messageReceived:(NSData *)data length:(int) len {
//- (void) messageReceived:(PBCodedInputStream*) input {
    
    //Response *resp = [Request parseFromCodedInputStream:input];
    Response *resp;
    @try
    {
        resp = [Response parseFromData:data];
    }
    @catch(NSException* ex)
    {
        NSLog(@"Error parsing incoming MSG, likely a GAE candidate");
        //NSLog(@"Bug captured data:%@", data);
        //NSString *message = [[resp webrtcMsg] json];
        //NSLog(@"Your msg - %@", message);
        //** skip ahead in data, and find 7B char, create NSData starting from this point in object
        //NSMutableString *result = [NSMutableString string];
        const char *bytes = [data bytes];
        int start = 0;
        int end = 0;
        NSError *error = nil;
        NSData *jsonBuf;
        NSDictionary *objects;
        NSLog(@"Data len: %d", [data length]);
        for (int i = 0; i < [data length]; i++)
        {
            if ( (unsigned char)bytes[i] == '{' && start == 0 ) {
                start = i;
                continue;
            }
            
            if ( (unsigned char)bytes[i] == '}' && end == 0 ) {
                end = i;
                jsonBuf  = [NSData dataWithBytes:([data bytes] + start)
                                          length:(end - start + 1)];
                
                objects     = [NSJSONSerialization JSONObjectWithData:jsonBuf
                                                        options:NSJSONReadingMutableContainers
                                                             error:&error];
                if (error != 0 ) {
                    NSLog(@"Error parsing candidate info from SERVER!");
                    break;
                }
                NSLog(@"Candidates obj: %@", objects);
                [(APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate] setCandidate:objects];
                start = end = 0;
                continue;
            }
        }
        NSLog(@"END exception handle");
        
        //**
        return;
    }

    Response_ResponseType rt = [resp type];
    NSLog(@"resp type: %u", rt);
    
    if ( rt ==  Response_ResponseTypeAuth )
    {
        NSLog(@"Response_ResponseTypeAuth");
        AuthResponse *authResp = [resp authResponse];
        if ( [authResp type] == AuthResponse_AuthResponseTypeAuthOk ) {
            //** we authenticated successfully, check if we received a session token
            if ( [authResp hasSessionToken] ) {
                NSLog(@"session token is: %@", [authResp sessionToken]);
                //** saves to DB as part of session and connection info
                //  dbHandler.updateSessionToken(connectionInfo, authResponse.getSessionToken());
                
                //** set TOKEN
                self.token = [authResp sessionToken];
                //** advance state machine
                //** TBD
            }
            else {
                NSLog(@"auth resp FAIL");
                // should be an AuthResponse with a type of AUTH_FAIL, but fail anyway if it isn't
                // if we used a session token and authentication failed, discard it
                //dbHandler.updateSessionToken(connectionInfo, "");
            }
        }
    }
    else if ( rt == Response_ResponseTypeVmready ) {
        NSLog(@"Response_ResponseTypeVmready  - VM READY!!");
        
        //** advance state machine
        NSLog(@"Querying for webrtc channel info");
        
        Request_Builder* rBuild = [Request builder];
        [rBuild setType:Request_RequestTypeVideoParams];
        
        Request* request = [rBuild build];
        [self sendSVMPMessage:request];
/*
        toastMe( "Querying for webrtc channel info" );
        
        // send video info request
        Request.Builder req = Request.newBuilder();
        req.setType(RequestType.VIDEO_PARAMS);
        req.build().writeDelimitedTo(socketOut);
*/
    }
    else if ( rt == Response_ResponseTypeVidstreaminfo ) { // || [resp videoInfo] ) {
        NSLog(@"Response_ResponseTypeVidstreaminfo  - VIDEO params!!");
        
        NSLog(@"vid params: %@", [resp videoInfo]);
        //if (++cnt < 2)
        [self processSVMPVideoParams:resp];
        
/*
        // get video info response
        Response resp = Response.parseDelimitedFrom(socketIn);
        
        // parse it and populate a SignalingParams
        if (resp.getType() == ResponseType.VIDSTREAMINFO || resp.hasVideoInfo())
            return getParametersForRoom(resp.getVideoInfo());
*/
    }
    else if ( rt == Response_ResponseTypeWebrtc || rt == Response_ResponseTypeVideostop ) {
        NSLog(@"Response_ResponseTypeWebrtc  - WEBRTC!!");
        [(APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate] onMessage:resp];
    }
    else if ( rt == Response_ResponseTypeScreeninfo ) {
        NSLog(@"Response_ResponseTypeWebrtc  - SCREENINFO");
        APPRTCAppDelegate *ad = (APPRTCAppDelegate *)[[UIApplication sharedApplication] delegate];
        [[[ad viewController] videoView] handleScreenInfoResponse:resp];
        
    }
    else {
        NSLog(@"unknown Message");
    }
    
    //** free this inbound buffer
    inputBuffer = nil;
}


@end
