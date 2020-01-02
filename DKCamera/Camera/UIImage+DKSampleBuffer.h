//
//  UIImage+MMSampleBuffer.h
//  MMHousehold
//
//  Created by Dikey on 16/02/2017.
//  Copyright © 2017 Netease. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef struct opaqueCMSampleBuffer *CMSampleBufferRef;

@interface UIImage (DKSampleBuffer)

+(UIImage *)dk_imageFromSampleBufferY420:(CMSampleBufferRef)sampleBuffer;
+(UIImage *)dk_imageFromSampleBuffer32BGRA:(CMSampleBufferRef)sampleBuffer;

@end
