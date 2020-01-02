//
//  MMCameraView.m
//  MMCamera
//
//  Created by Dikey on 4/28/16.
//  Copyright © 2016 dikey. All rights reserved.
//

#import "DKCameraView.h"
#import <AVFoundation/AVFoundation.h>

@implementation DKCameraView

+ (Class)layerClass
{
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureSession *)session
{
    return [(AVCaptureVideoPreviewLayer *)[self layer] session];
}

- (void)setSession:(AVCaptureSession *)session
{
    [(AVCaptureVideoPreviewLayer *)[self layer] setSession:session];
}

@end
