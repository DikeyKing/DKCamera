//
//  MMCameraView.h
//  MMCamera
//
//  Created by Dikey on 4/28/16.
//  Copyright © 2016 dikey. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AVCaptureSession;

@interface DKCameraView : UIView

@property (nonatomic) AVCaptureSession *session;

@end
