#import "BallerViewController.h"
#import "BallerImageHelper.h"
#import "BallerImageProcessController.h"
#import "Utilities.h"
#import <QuartzCore/QuartzCore.h>


@interface BallerViewController ()
//@property (nonatomic, retain) NSTimer *nextFrameTimer;

@property (nonatomic) BallerImageProcessController *leftVideoController;
@property (nonatomic) BallerImageProcessController *rightVideoController;

@property float leftVideoMotionIntensity;
@property float rightVideoMotionIntensity;


// number corresponds to number of the most recent 10 that corresponds to left/right video
@property int chooseLeftState;
@property int chooseRightState;

@end

@implementation BallerViewController



#define FRAMES ((int)33)
#define WIDTH ((int)1280)
#define HEIGHT ((int)720)

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        
//        NSString *URL = @"rtsp://52.87.63.85:1935/vods3/_definst_/amazons3/ballerstaging-assets/left1_720.mp4";
//        NSString *URL1 = @"rtsp://52.87.63.85:1935/vods3/_definst_/amazons3/ballerstaging-assets/right1_720.mp4";
        
//        NSString *URL = @"rtsp://192.168.0.180:554/11";
//        NSString *URL = @"rtsp://eugene:eugene123@192.168.0.108:554";
        
//        NSString *URL = @"rtsp://52.87.63.85:1935/live/Amcrest1080.stream";
        
        NSString *URL = @"rtsp://admin:Baller*269@192.168.0.51";
        NSString *URL1 = @"rtsp://admin:Baller*269@192.168.0.51";

        
        
        self.leftVideoController = [[BallerImageProcessController alloc] init];
        self.rightVideoController = [[BallerImageProcessController alloc] init];
        
        int w = WIDTH;
        int h = HEIGHT;
        BOOL FLAG = true;
        
        _counter = 0;
        _selected = 1;
        inBackground = false;
        
        _video = [[RTSPPlayer alloc] initWithVideo:URL usesTcp:FLAG usesAudio:FALSE withName:@"first"];
        [_video setDelegate:self];
        _video.outputWidth = w;
        _video.outputHeight = h;
        
        _video1 = [[RTSPPlayer alloc] initWithVideo:URL1 usesTcp:FLAG usesAudio:FALSE withName:@"second"];
        [_video1 setDelegate:self];
        _video1.outputWidth = w;
        _video1.outputHeight = h;
        
        NSLog(@"video duration: %f",_video.duration);
        NSLog(@"video size: %d x %d", _video.sourceWidth, _video.sourceHeight);
        
        __sessionQueue = dispatch_queue_create("capture_session_queue", DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

- (void)dealloc
{
    [_video release];
    _video = nil;
    
    [_imageViewLeft release];
    _imageViewLeft = nil;
    
    [_video1 release];
    _video1 = nil;
    
    [_imageViewRight release];
    _imageViewRight = nil;
    
    [_processedViewLeft release];
    _processedViewLeft = nil;
    
    [_processedViewRight release];
    _processedViewRight = nil;
    
    [_imageViewSmall release];
    _imageViewSmall = nil;
    
    [_imageViewBig release];
    _imageViewBig = nil;
    
    
    [_broadcastButton release];
    _broadcastButton = nil;
    
    
    [_motionLeft release];
    [_motionRight release];
    [_processedViewLeft release];
    [_processedViewRight release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [_imageViewLeft setContentMode:UIViewContentModeScaleAspectFit];
    [_imageViewRight setContentMode:UIViewContentModeScaleAspectFit];
    
    [_imageViewSmall setContentMode:UIViewContentModeScaleAspectFill];
    [_imageViewBig setContentMode:UIViewContentModeScaleAspectFill];
   
    [self initStream];
    [self playRTSPStreams];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)broadcastButtonAction:(id)sender {
    _broadcastButton.enabled = NO;
    
    if(!streamStarted) {
        [_stream start:^(NSXError err)
         {
             // use main queue to change UI related things
             dispatch_async(dispatch_get_main_queue(), ^
                            {
                                if (err == NSXErrorNone)
                                {
                                    // Handle succesful stream start
                                    streamStarted = true;
                                    [_broadcastButton setTitle:@"Stop" forState:UIControlStateNormal];
                                }
                                else
                                {
                                    // Handle failure
                                    streamStarted = false;
                                    NSLog(@"stream start failed");
                                }
                                _broadcastButton.enabled = YES;
                            }); // end main stream
         } // end stream start
         ];
    }else{ // if stream already started, lets stop streaming here
        streamStarted = false;
        [_stream stop:true withCompletion:^(void){
            dispatch_async(dispatch_get_main_queue(), ^{
                _counter = 0;
                streamStarted = false;
                [_customSession reset];
                [_broadcastButton setTitle:@"Start" forState:UIControlStateNormal];
                _broadcastButton.enabled = YES;
            });
        }];
    }
}

- (IBAction)selectFirst {
    _selected = 1;
    NSLog(@"selectFirst %d", (int)_selected);
}

- (IBAction)selectSecond {
    _selected = 2;
    NSLog(@"selectSecond %d", (int)_selected);
}

-(void)playRTSPStreams {
    lastFrameTime = -1;
    
    // seek to 0.0 seconds
    [_video seekTime:0.0];
    [_video1 seekTime:0.0];
    
//    [_nextFrameTimer invalidate];
//    self.nextFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/FRAMES
//                                                           target:self
//                                                         selector:@selector(displayNextFrame:)
//                                                         userInfo:nil
//                                                          repeats:YES];
//
    dispatch_async(__sessionQueue, ^{
        while(1){
            [_video stepFrame];
            [_video1 stepFrame];
        }
    });
    
    _counter = 0;
}


- (void) initStream {
    nanostreamAVCSettings *nAVCSettings = [[nanostreamAVCSettings alloc] init];
    
    [nAVCSettings setUrl:@"rtmp://52.87.63.85:1935/live"];
    [nAVCSettings setStreamId:@"myStream"];
    
    nanoStreamResolution videoResolution = Resolution640x480;
    nanostreamCropMode cropMode = CropTo640x360;
    int frameRate = FRAMES;
    float keyFrameDistance = 2.0;
    nanoStreamH264ProfileLevel h264Level = MainAutoLevel;
    NSXStreamType streamType = NSXStreamTypeVideoOnly;
    AdaptiveBitrateControlMode abcMode = AdaptiveBitrateControlModeFrameDrop;
    
    // H264 Video Encoding Bitrate
    // Note: this is the average bitrate used
    // When using adaptive bitrate, it can decrease down to 50k and increase to 1.5xbitrate
    // If automatic is selected in settings, the bitrate determined over the bandwidth ckeck will used
    [nAVCSettings setVideoBitrate:500];
    
    //VBR
    [nAVCSettings setH264RateControl:NSXH264RateControlVBR1];
    
    // Camera and stream resolution
    [nAVCSettings setVideoResolution:videoResolution];
    [nAVCSettings setCropMode:cropMode];
    [nAVCSettings setKeyFrameInterval:keyFrameDistance];
    [nAVCSettings setFramerate:frameRate];
    
    // H264 Encoder Profile (Baseline/Main)
    [nAVCSettings setH264Level:h264Level];
    
    // Video+Audio or Video-only or Audio-only
    [nAVCSettings setStreamType:streamType];
    
    // Front/Back Cam
    [nAVCSettings setFrontCamera:NO];
    
    int nanostreamAvcVersion = [nanostreamAVC getVersion];
    NSLog(@"nanoStream Version: %i %i", nanostreamAvcVersion, NANOSTREAM_AVC_VERSION);
    
    if (nanostreamAvcVersion != NANOSTREAM_AVC_VERSION) {
        NSLog(@"nanoStream Version Mismatch - need recompile - %d %d", nanostreamAvcVersion, NANOSTREAM_AVC_VERSION);
    }
    
    // create session object for redirecting "custom" video frames to the nanostreamAVC library
    _customSession = [[NSXCustomCaptureSession alloc] init];
    
    // nanoStream Init Encoder with the camera view
    _stream = [[nanostreamAVC alloc] initWithSession:_customSession settings:nAVCSettings errorListener:self];
    
    [_stream setAuthentication:@"eugene" withPassword:@"eugene"];
    
    // Set Loglevel
    [_stream SetLogLevel:LogLevelMinimal];
    
    // nanoStream License
    [_stream setLicense:myLicenseKey];
    
    // Adaptive Bitrate ON (Full)
    [_stream setAbcMode:abcMode];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_broadcastButton setEnabled:YES];
    });
}



#define LERP(A,B,C) ((A)*(1.0-C)+(B)*C)

//-(void)displayNextFrame:(NSTimer *)timer{
//    if(!inBackground)
//       [self executeDisplayNextFrame:timer];
//}
//
//-(void)executeDisplayNextFrame:(NSTimer *)timer
//{
//    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
//
//    @try{
//        if (![video stepFrame]) {
//            [timer invalidate];
//            [video closeAudio];
//            return;
//        }
//        imageViewLeft.image = video.currentImage;
//    }@catch(NSException *exception) {
//        NSLog(@"Failed to get stepFrame for video 1");
//    }
//
//    @try{
//        if (![video1 stepFrame]) {
//            [timer invalidate];
//            [video1 closeAudio];
//            return;
//        }
//        imageViewRight.image = video1.currentImage;
//    }@catch(NSException *exception) {
//        NSLog(@"Failed to get stepFrame for video 1");
//    }
//
//    if(selected == 1) {
//        backgroundImage = video.currentCIImage;
//        foregroundImage = video1.currentCIImage;
//    }else{
//        backgroundImage = video1.currentCIImage;
//        foregroundImage = video.currentCIImage;
//    }
//
//    imageViewSmall.image = [UIImage imageWithCIImage:backgroundImage];
//    imageViewBig.image = [UIImage imageWithCIImage:foregroundImage];
//
//}

-(NSString *)getViewName:(NSString *)name withImage:(UIImage*)image
{
    @autoreleasepool {
//        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
//        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSSSSSSZZZZZ"];
        
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *im;
            [self.leftVideoController convertImage:image];
            [self.leftVideoController histogram];
            BOOL oex = [self.leftVideoController overexposed];
            BOOL uex = [self.leftVideoController underexposed];
            im = [self.leftVideoController autoBrightnessContrast];
            
            if([name isEqualToString:@"first"]){
                [_imageViewLeft setImage:image];
                
    //            NSLog(@"getViewName1 %@ and name %@",[formatter stringFromDate:[NSDate date]], name);
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    self.leftVideoMotionIntensity = [self.leftVideoController computeMotionIntensity:image];
//                    UIImage *threshold = [self.leftVideoController thresholdedImage:image];

                    dispatch_async(dispatch_get_main_queue(), ^{
//                        [_processedViewLeft setImage:leftImg];
                        self.motionLeft.text = [NSString stringWithFormat:@"%.2f", self.leftVideoMotionIntensity];
//                        [_processedViewLeft setImage:threshold];
                    });
                });

                
            }else if([name isEqualToString:@"second"]){
                [_imageViewRight setImage:image];
                
    //            NSLog(@"getViewName2 %@ and name %@",[formatter stringFromDate:[NSDate date]], name);
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    self.rightVideoMotionIntensity = [self.rightVideoController computeMotionIntensity:image];
//                    UIImage *thresholdRight = [self.rightVideoController thresholdedImage:image];

                    dispatch_async(dispatch_get_main_queue(), ^{
//                        [_processedViewRight setImage:rightImg];
                        self.motionRight.text = [NSString stringWithFormat:@"%.2f", self.rightVideoMotionIntensity];
//                        [_processedViewRight setImage:thresholdRight];
                    });
                });

            }
            
            // check (force 2 consecutive frames of the same video before changing)
            if (self.leftVideoMotionIntensity > self.rightVideoMotionIntensity) {
                
                self.chooseLeftState++;
                if (self.chooseLeftState > FRAMES/3) {
                    _selected = 1;
                    self.chooseRightState = 0;
                    self.chooseLeftState = 0;
                }
                
            } else if (self.rightVideoMotionIntensity > self.leftVideoMotionIntensity) {
                
                self.chooseRightState++;
                if (self.chooseRightState > FRAMES/3) {
                    _selected = 2;
                    self.chooseLeftState = 0;
                    self.chooseRightState = 0;
                }
            }
            
            [_imageViewBig setImage:im];
//            if (_selected == 1) {
//                [_imageViewBig setImage:_imageViewLeft.image];
//            } else {
//                [_imageViewBig setImage:_imageViewRight.image];
//            }
            
            CGImageRef cgImage = _imageViewBig.image.CGImage;
            
            
//            if(_selected == 1) {
//                [_imageViewSmall setImage:_imageViewLeft.image];
//                [_imageViewBig setImage:_imageViewRight.image];
//            }else{
//                [_imageViewSmall setImage:_imageViewRight.image];
//                [_imageViewBig setImage:_imageViewLeft.image];
//            }
//
//            UIGraphicsBeginImageContextWithOptions(mixedView.bounds.size, mixedView.opaque, 0.0);
//            [mixedView.layer renderInContext:UIGraphicsGetCurrentContext()];
//
//            UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
//            UIGraphicsEndImageContext();
//
//            CGImageRef cgImage = img.CGImage;
            
            
            
            if(streamStarted){
                if(!inBackground){
                    CVImageBufferRef pixelBuffer = NULL;
                    pixelBuffer = [BallerImageHelper pixelBufferFromCGImage: cgImage];
                    [_customSession supplyVideoBuffer:pixelBuffer];
                    [pixelBuffer release];
                }
            }
            
            [image release];
        });
    }
    
    return @"";
}


// nano stream related implementations

- (void)nanostreamEventHandlerWithType:(nanostreamEvent)type andLevel:(int)level andDescription:(NSString *)description {
    switch (type) {
        case StreamStarted:
            break;
        case StreamStopped:
            break;
        case StreamError:
            NSLog(@"nanostreamEventHandlerWithType: StreamError: %@", description);
            break;
        case StreamErrorConnect:
            NSLog(@"nanostreamEventHandlerWithType: StreamErrorConnect: %@", description);
            break;
        case StreamConnectionStatus:
            NSLog(@"nanostreamEventHandlerWithType: RtmpConnectionStatus %@", description);
            break;
        case GeneralError:
            break;
        default:
            break;
    }
}

-(void)activateBackground {
    inBackground = true;
}

-(void)activateForeground {
    inBackground = false;
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    //    <#code#>
}

- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection {
    //    <#code#>
}

- (void)preferredContentSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container {
    //    <#code#>
}

- (CGSize)sizeForChildContentContainer:(nonnull id<UIContentContainer>)container withParentContainerSize:(CGSize)parentSize {
    //    <#code#>
    return CGSizeZero;
}

- (void)systemLayoutFittingSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container {
    //    <#code#>
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator {
    //    <#code#>
}

- (void)willTransitionToTraitCollection:(nonnull UITraitCollection *)newCollection withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator {
    //    <#code#>
}

- (void)didUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context withAnimationCoordinator:(nonnull UIFocusAnimationCoordinator *)coordinator {
    //    <#code#>
}

- (void)setNeedsFocusUpdate {
    //    <#code#>
}

- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context {
    //    <#code#>
    return NO;
}

- (void)updateFocusIfNeeded {
    //    <#code#>
}

@end

