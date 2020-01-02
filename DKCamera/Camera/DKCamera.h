//
//  MMCamera.h
//  MMCamera
//
//  Created by Dikey on 4/28/16.
//  Copyright © 2016 dikey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

//@import AVFoundation;

@protocol MMCameraDelegate <NSObject>

@optional

/*32 bit BGRA 视频流 */
- (void)willOutputSampleBuffer:(CMSampleBufferRef )sampleBuffer;

@end

@interface DKCamera : UIViewController

@property (nonatomic,weak) id<MMCameraDelegate> cameraDelegate;

-(void)startCamera;//初始化方法一
-(void)startCameraWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition;//初始化方法二
-(void)startRunning;//开启相机
-(void)stopRunning;//需要进入后台时候停掉相机
-(void)pauseCamera;//需要退出界面的时候暂停相机
-(void)resumeCamera; //需要在退出界面的时候暂停
-(void)changeLensPosition:(float)value;//改变焦距（0~1）
-(void)snapStillImage;//拍照并保存照片，后续考虑返回UIImage
- (void)switchFormatWithDesiredFPS:(CGFloat)desiredFPS;

@end
