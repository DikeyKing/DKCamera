//
//  ViewController.m
//  DKCamera
//
//  Created by Dikey on 2020/1/2.
//  Copyright © 2020 Dikey. All rights reserved.
//

#import "ViewController.h"
#import "DKImageConverter.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<MMCameraDelegate>{
    EAGLContext *eaglctx;
    CIContext *context;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    // 创建基于 GPU 的 CIContext 对象
//    eaglctx = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
//    context = [CIContext contextWithEAGLContext:eaglctx];
//    context = [CIContext contextWithOptions: nil];
    context = [CIContext contextWithOptions: [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:kCIContextUseSoftwareRenderer]];

    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if (granted){
            dispatch_async(dispatch_get_main_queue(), ^{
                [self startCamera];
                [self startRunning];
                self.cameraDelegate = self;
            });
        }
    }];
}

- (void)dealloc
{
    [self stopRunning];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)willOutputSampleBuffer:(CMSampleBufferRef )sampleBuffer
{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (pixelBuffer == NULL) { return; }

    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);

    CGRect videoRect = CGRectMake(0, 0, width, height);
    CGSize scaledSize = CGSizeMake(400 , 400 );
//    CGRect cropRect = CGRectMake(100, 400, 400, 400);
    
    // Create a rectangle that meets the output size's aspect ratio, centered in the original video frame
    CGRect centerCroppingRect = AVMakeRectWithAspectRatioInsideRect(scaledSize, videoRect);

    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    
    CVPixelBufferRef cropped = vImageCropPixelBuffer(pixelBuffer, centerCroppingRect);
    CVPixelBufferRef croppedAndScaled = vImageConvertPixelBuffer(pixelBuffer, centerCroppingRect, scaledSize);
//    CVPixelBufferRef rotated = vImageRotatePixelBuffer(croppedAndScaled, 3);

    CFAbsoluteTime currentTime1 = CFAbsoluteTimeGetCurrent();
    NSLog(@"耗时1 = %f" , currentTime1 -  currentTime );

//    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
//    CVPixelBufferRef croppedAndScaled2 = createCroppedPixelBufferCoreImageWithContext(pixelBuffer, 6 , centerCroppingRect, scaledSize, context);
//    CFAbsoluteTime currentTime2 = CFAbsoluteTimeGetCurrent();
//    NSLog(@"耗时3 = %f" , currentTime2 - currentTime);

    // For example
//    CIImage *image = [CIImage imageWithCVImageBuffer:croppedAndScaled];
//    UIImage *resultImage = [UIImage imageWithCIImage:image];
//    NSLog(@"resultImage is %@", resultImage);
    // End example

//    CVPixelBufferRelease(cropped);
    CVPixelBufferRelease(croppedAndScaled);
//    CVPixelBufferRelease(croppedAndScaled2);
//    CVPixelBufferRelease(rotated);
}

@end
