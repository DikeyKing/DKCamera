//
//  MMCamera.m
//  MMCamera
//
//  Created by Dikey on 4/28/16.
//  Copyright © 2016 dikey. All rights reserved.
//

#import "DKCamera.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "DKCameraView.h"

static void *CapturingStillImageContext = &CapturingStillImageContext;
static void *RecordingContext = &RecordingContext;
static void *SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;

@interface DKCamera ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    BOOL capturePaused;
    BOOL lensLocked;
}

@property (nonatomic, strong) DKCameraView* previewView;
@property (nonatomic, strong) NSArray *focusModes;
@property (nonatomic, strong) NSArray *exposureModes;
@property (nonatomic, strong) NSArray *whiteBalanceModes;

@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureDevice *videoDevice;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic) AVCaptureVideoDataOutput *avCaptureVideoDataOutput;

@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;
@property (nonatomic) id startErrorHandlingObserver;
@property (nonatomic) id didStartRunningHandlingObserver;
@property (nonatomic) id didStopRunningHandlingObserver;
@property (nonatomic) id wasInterruptedHandlingObserver;

@end

@implementation DKCamera

static UIColor* CONTROL_NORMAL_COLOR = nil;
static UIColor* CONTROL_HIGHLIGHT_COLOR = nil;
static float EXPOSURE_DURATION_POWER = 5; // Higher numbers will give the slider more sensitivity at shorter durations
static float EXPOSURE_MINIMUM_DURATION = 1.0/1000; // Limit exposure duration to a useful range

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self addObservers];
}

-(void)startCamera
{
    [self startCameraWithSessionPreset:AVCaptureSessionPresetPhoto cameraPosition:AVCaptureDevicePositionBack];//包括拍照/视频流
}

-(void)startCameraWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition
{
    [self checkDeviceAuthorizationStatus];
    [self addCameraPreviewView];//增加相机预览界面

    capturePaused = NO;
    lensLocked = NO;
    
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in cameras) {
        if (device.position == AVCaptureDevicePositionBack) {
            _videoDevice = device;
        }
    }
    NSError *error = nil;
    _videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_videoDevice error:&error];
    if (!_videoDeviceInput){
        NSLog(@"error is %@",error);
        return;
    }
    _session = [[AVCaptureSession alloc] init];
    _session.sessionPreset = sessionPreset;
    
    [_session beginConfiguration];
    
    if ([_session canAddInput:_videoDeviceInput]){
        [self setVideoDevice:_videoDeviceInput.device];
        [_session addInput:_videoDeviceInput];
    }
    _avCaptureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    NSDictionary*settings = @{(__bridge id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    _avCaptureVideoDataOutput.videoSettings = settings;
    _sessionQueue = dispatch_queue_create("com.netease.multimedia", NULL);
    [_avCaptureVideoDataOutput setSampleBufferDelegate:self queue:_sessionQueue];
    [_session addOutput:_avCaptureVideoDataOutput];
    
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{//界面相关，在主线程中处理
            [[(AVCaptureVideoPreviewLayer *)[_previewView layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)[self interfaceOrientation]];
        });
    }
    _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    if ([_session canAddOutput:_stillImageOutput]){
        [_stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
        [_session addOutput:_stillImageOutput];
        [self setStillImageOutput:_stillImageOutput];
    }
    
    [_previewView setSession:_session];
    AVCaptureVideoPreviewLayer* layer = (AVCaptureVideoPreviewLayer*)_previewView.layer;
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    [[self session] commitConfiguration];
}

-(void)addCameraPreviewView
{
    _previewView = [[DKCameraView alloc]init];
    [self.view addSubview:_previewView];
    [self addConstrains];
    // _previewView.hidden = YES;
}

-(void)startRunning
{
    if (self.isDeviceAuthorized ) {
        if (![_session isRunning]) {
            [_session startRunning];
        }
    }else{
        
    }
}

-(void)stopRunning
{
    dispatch_async([self sessionQueue], ^{
        if ([_session isRunning]) {
            [_session stopRunning];
        }
    });
}

- (void)pauseCamera;
{
    capturePaused = YES;
}

- (void)resumeCamera;
{
    capturePaused = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (capturePaused)
    {
        return;
    }
    if ([self.cameraDelegate respondsToSelector:@selector(willOutputSampleBuffer:)]) {
        [self.cameraDelegate willOutputSampleBuffer:sampleBuffer];
    }
}

#pragma mark: Orientation
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)toInterfaceOrientation];
    NSLog(@"willRotateToInterfaceOrientation :%@",NSStringFromCGRect(_previewView.frame));
}
#pragma mark:constains
-(void)addConstrains
{
    _previewView.translatesAutoresizingMaskIntoConstraints = NO;
    UIEdgeInsets padding = UIEdgeInsetsMake(0, 0, 0, 0);
    [self.view addConstraints:@[
                                
                                //view1 constraints
                                [NSLayoutConstraint constraintWithItem:_previewView
                                                             attribute:NSLayoutAttributeTop
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeTop
                                                            multiplier:1.0
                                                              constant:padding.top],
                                
                                [NSLayoutConstraint constraintWithItem:_previewView
                                                             attribute:NSLayoutAttributeLeft
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeLeft
                                                            multiplier:1.0
                                                              constant:padding.left],
                                
                                [NSLayoutConstraint constraintWithItem:_previewView
                                                             attribute:NSLayoutAttributeBottom
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeBottom
                                                            multiplier:1.0
                                                              constant:-padding.bottom],
                                
                                [NSLayoutConstraint constraintWithItem:_previewView
                                                             attribute:NSLayoutAttributeRight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeRight
                                                            multiplier:1
                                                              constant:-padding.right],
                                ]];
    
    
}

#pragma mark:helper

- (BOOL)isSessionRunningAndDeviceAuthorized
{
    return [[self session] isRunning] && [self isDeviceAuthorized];
}

- (void)snapStillImage
{
    [self runStillImageCaptureAnimation];
    dispatch_async([self sessionQueue], ^{
        // Update the orientation on the still image output video connection before capturing.
        [[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer*)[self.previewView layer] connection] videoOrientation]];
        [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            if (imageDataSampleBuffer)
            {
                NSLog(@"save image");
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                UIImage *image = [[UIImage alloc] initWithData:imageData];
                [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
            }
        }];
    });
}

- (void)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer
{
    if (self.videoDevice.focusMode != AVCaptureFocusModeLocked && self.videoDevice.exposureMode != AVCaptureExposureModeCustom)
    {
        CGPoint devicePoint = [(AVCaptureVideoPreviewLayer *)_previewView captureDevicePointOfInterestForPoint:[gestureRecognizer locationInView:[gestureRecognizer view]]];
        [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
    }
}

-(void)changeFocusMode:(AVCaptureFocusMode)mode
{
    NSError *error = nil;
    self.videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([self.videoDevice lockForConfiguration:&error])
    {
        if ([self.videoDevice isFocusModeSupported:mode])
        {
            self.videoDevice.focusMode = mode;
            lensLocked = (mode == AVCaptureFocusModeLocked)?YES:NO;
        }else{
            NSLog(@"Focus mode %ld is not supported.", (long)mode);
        }
        [self.videoDevice unlockForConfiguration];
    }else{
        NSLog(@"%@", error);
    }
}

- (void)changeLensPosition:(float)value
{
    NSError *error = nil;
    [self changeFocusMode:AVCaptureFocusModeLocked];
    if ([self.videoDevice lockForConfiguration:&error]){
        [self.videoDevice setFocusModeLockedWithLensPosition:value completionHandler:^(CMTime syncTime) {
            NSLog(@"self.videoDevice.lensPosition : %f", [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo].lensPosition);
        }];
        [self.videoDevice unlockForConfiguration];
    }else{
        NSLog(@"%@", error);
    }
}

- (void)changeExposureDuration:(float)value
{
    NSError *error = nil;
    double p = pow( value, EXPOSURE_DURATION_POWER ); // Apply power function to expand slider's low-end range
    double minDurationSeconds = MAX(CMTimeGetSeconds(self.videoDevice.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
    double maxDurationSeconds = CMTimeGetSeconds(self.videoDevice.activeFormat.maxExposureDuration);
    double newDurationSeconds = p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds; // Scale from 0-1 slider range to actual duration
    if ([self.videoDevice lockForConfiguration:&error])
    {
        [self.videoDevice setExposureModeCustomWithDuration:CMTimeMakeWithSeconds(newDurationSeconds, 1000*1000*1000)  ISO:AVCaptureISOCurrent completionHandler:nil];
        [self.videoDevice unlockForConfiguration];
    }else{
        NSLog(@"%@", error);
    }
}

- (void)changeISO:(float)value
{
    NSError *error = nil;
    if ([self.videoDevice lockForConfiguration:&error])
    {
        [self.videoDevice setExposureModeCustomWithDuration:AVCaptureExposureDurationCurrent ISO:value completionHandler:nil];
        [self.videoDevice unlockForConfiguration];
    }else{
        NSLog(@"%@", error);
    }
}

- (void)changeExposureTargetBias:(float)value
{
    NSError *error = nil;
    if ([self.videoDevice lockForConfiguration:&error]){
        [self.videoDevice setExposureTargetBias:value completionHandler:nil];
        [self.videoDevice unlockForConfiguration];
    }else{
        NSLog(@"%@", error);
    }
}

- (void)changeTemperature:(float)value
{
    AVCaptureWhiteBalanceTemperatureAndTintValues temperatureAndTint = {
        .temperature = value,
    };
    [self setWhiteBalanceGains:[self.videoDevice deviceWhiteBalanceGainsForTemperatureAndTintValues:temperatureAndTint]];
}

- (void)changeTint:(float)value
{
    AVCaptureWhiteBalanceTemperatureAndTintValues temperatureAndTint = {
        .tint = value,
    };
    [self setWhiteBalanceGains:[self.videoDevice deviceWhiteBalanceGainsForTemperatureAndTintValues:temperatureAndTint]];
}

#pragma mark UI
- (void)runStillImageCaptureAnimation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [(AVCaptureVideoPreviewLayer*)[self.previewView layer] setOpacity:0.0];
        [UIView animateWithDuration:.25 animations:^{
            [(AVCaptureVideoPreviewLayer*)[self.previewView layer] setOpacity:1.0];
        }];
    });
}

#pragma mark File Output Delegate
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    if (error){
        NSLog(@"%@", error);
    }
    [self setLockInterfaceRotation:NO];
    // Note the backgroundRecordingID for use in the ALAssetsLibrary completion handler to end the background task associated with this recording. This allows a new recording to be started, associated with a new UIBackgroundTaskIdentifier, once the movie file output's -isRecording is back to NO — which happens sometime after this method returns.
    UIBackgroundTaskIdentifier backgroundRecordingID = [self backgroundRecordingID];
    [self setBackgroundRecordingID:UIBackgroundTaskInvalid];
    [[[ALAssetsLibrary alloc] init] writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error){
            NSLog(@"%@", error);
        }
        NSLog(@"outputFileURL %@", outputFileURL);
        [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
        if (backgroundRecordingID != UIBackgroundTaskInvalid){
            [[UIApplication sharedApplication] endBackgroundTask:backgroundRecordingID];
        }
    }];
}

#pragma mark Device Configuration

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    dispatch_async([self sessionQueue], ^{
        AVCaptureDevice *device = [self videoDevice];
        NSError *error = nil;
        if ([device lockForConfiguration:&error]){
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode]){
                [device setFocusMode:focusMode];
                [device setFocusPointOfInterest:point];
            }
            if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode]){
                [device setExposureMode:exposureMode];
                [device setExposurePointOfInterest:point];
            }
            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        }else{
            NSLog(@"%@", error);
        }
    });
}

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
    if ([device hasFlash] && [device isFlashModeSupported:flashMode]){
        NSError *error = nil;
        if ([device lockForConfiguration:&error]){
            [device setFlashMode:flashMode];
            [device unlockForConfiguration];
        }else{
            NSLog(@"%@", error);
        }
    }
}

- (void)setWhiteBalanceGains:(AVCaptureWhiteBalanceGains)gains
{
    NSError *error = nil;
    
    if ([self.videoDevice lockForConfiguration:&error]){
        AVCaptureWhiteBalanceGains normalizedGains = [self normalizedGains:gains]; // Conversion can yield out-of-bound values, cap to limits
        [self.videoDevice setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:normalizedGains completionHandler:nil];
        [self.videoDevice unlockForConfiguration];
    }else{
        NSLog(@"%@", error);
    }
}

#pragma mark Observers
- (void)addObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[self videoDevice]];
    
    __weak DKCamera *weakSelf = self;
    [self setRuntimeErrorHandlingObserver:[[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:[self session] queue:nil usingBlock:^(NSNotification *note) {
        DKCamera *strongSelf = weakSelf;
        dispatch_async([strongSelf sessionQueue], ^{
            // Manually restart the session since it must have been stopped due to an error
            [[strongSelf session] startRunning];
        });
    }]];
    
    [self setDidStartRunningHandlingObserver:[[NSNotificationCenter defaultCenter]addObserverForName:AVCaptureSessionDidStartRunningNotification object:[self session] queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        NSLog(@"Thread is %@ did started",[NSThread currentThread]);
    }]];
    
    [self setDidStopRunningHandlingObserver:[[NSNotificationCenter defaultCenter]addObserverForName:AVCaptureSessionDidStopRunningNotification object:[self session] queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        NSLog(@"Thread is %@ did Stop",[NSThread currentThread]);
    }]];
    
    [self setWasInterruptedHandlingObserver:[[NSNotificationCenter defaultCenter]addObserverForName:AVCaptureSessionWasInterruptedNotification object:[self session] queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        NSLog(@"setWasInterruptedHandlingObserver");
    }]];
}

- (void)removeObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[self videoDevice]];
    [[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
    if (lensLocked) {
        return;
    }
    CGPoint devicePoint = CGPointMake(.5, .5);
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

#pragma mark Utilities

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = [devices firstObject];
    for (AVCaptureDevice *device in devices){
        if ([device position] == position){
            captureDevice = device;
            break;
        }
    }
    return captureDevice;
}

- (void)checkDeviceAuthorizationStatus
{
    NSString *mediaType = AVMediaTypeVideo;
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        if (granted){
            [self setDeviceAuthorized:YES];
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:@""
                                            message:@"请打开相机权限"
                                           delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil] show];
                [self setDeviceAuthorized:NO];
            });
        }
    }];
}

- (AVCaptureWhiteBalanceGains)normalizedGains:(AVCaptureWhiteBalanceGains) gains
{
    AVCaptureWhiteBalanceGains g = gains;
    g.redGain = MAX(1.0, g.redGain);
    g.greenGain = MAX(1.0, g.greenGain);
    g.blueGain = MAX(1.0, g.blueGain);
    g.redGain = MIN(self.videoDevice.maxWhiteBalanceGain, g.redGain);
    g.greenGain = MIN(self.videoDevice.maxWhiteBalanceGain, g.greenGain);
    g.blueGain = MIN(self.videoDevice.maxWhiteBalanceGain, g.blueGain);
    return g;
}

- (void)switchFormatWithDesiredFPS:(CGFloat)desiredFPS
{
    BOOL isRunning = self.session.isRunning;
    if (isRunning)  [self.session stopRunning];
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceFormat *selectedFormat = nil;
    int32_t maxWidth = 0;
    AVFrameRateRange *frameRateRange = nil;
    for (AVCaptureDeviceFormat *format in [videoDevice formats]) {
        for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
            CMFormatDescriptionRef desc = format.formatDescription;
            CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(desc);
            int32_t width = dimensions.width;
            if (range.minFrameRate <= desiredFPS && desiredFPS <= range.maxFrameRate && width >= maxWidth) {
                selectedFormat = format;
                frameRateRange = range;
                maxWidth = width;
            }
        }
    }
    if (selectedFormat) {
        if ([videoDevice lockForConfiguration:nil]) {
            NSLog(@"selected format:%@", selectedFormat);
            videoDevice.activeFormat = selectedFormat;
            videoDevice.activeVideoMinFrameDuration = CMTimeMake(1, (int32_t)desiredFPS);
            videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1, (int32_t)desiredFPS);
            [videoDevice unlockForConfiguration];
        }
    }
    AVCaptureConnection *conn = [[_session.outputs lastObject]connectionWithMediaType:AVMediaTypeVideo];
    if (conn.supportsVideoMaxFrameDuration) {
        conn.videoMaxFrameDuration = CMTimeMake(1, (int32_t)desiredFPS);
        conn.videoMinFrameDuration= CMTimeMake(1, (int32_t)desiredFPS);
    }
    if (isRunning) [self.session startRunning];
}

@end
