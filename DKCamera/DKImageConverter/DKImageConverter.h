//
//  AREImageCroper.h
//  MMCameraDemo
//
//  Created by Dikey on 2019/12/23.
//  Copyright © 2019 dikey. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>

@interface DKImageConverter : NSObject

#pragma mark - Core Image Convert

/// Corp、resize and orientate CVPixelBufferRef
/// @param pixelBuffer Input CVPixelBufferRef
/// @param orientation orientation
/// @param cropRect cropRect
/// @param scaleSize scaleSize
/// @param context context
CVPixelBufferRef createCroppedPixelBufferCoreImageWithContext(CVPixelBufferRef pixelBuffer,
                                                   int orientation,
                                                   CGRect cropRect,
                                                   CGSize scaleSize,
                                                   CIContext *context);

/// Corp、resize and orientate CVPixelBufferRef
/// @param pixelBuffer Input CVPixelBufferRef
/// @param orientation orientation
/// @param cropRect cropRect
/// @param scaleSize scaleSize
CVPixelBufferRef createCroppedPixelBufferCoreImage(CVPixelBufferRef pixelBuffer,
                                                                 int orientation,
                                                                 CGRect cropRect,
                                                                 CGSize scaleSize);

#pragma mark - vImage Convert

/// Corp、resize CVPixelBufferRef with vImage
/// @param sourcePixelBuffer sourcePixelBuffer
/// @param croppingRect croppingRect
/// @param scaledSize scaledSize
CVPixelBufferRef vImageConvertPixelBuffer(CVPixelBufferRef sourcePixelBuffer,
                                          CGRect croppingRect,
                                          CGSize scaledSize);

/// rotate CVPixelBufferRef
/// @param sourcePixelBuffer sourcePixelBuffer
/// @param rotationConstant 3 for Clockwise and 3 for Counterclockwise
CVPixelBufferRef vImageRotatePixelBuffer(CVPixelBufferRef sourcePixelBuffer,
                                         uint8_t rotationConstant);


/// rotate CVPixelBufferRef
/// @param sourcePixelBuffer sourcePixelBuffer
/// @param rotationConstant 3 for Clockwise and 3 for Counterclockwise
/// @param reflect reflect
/// @param horizontal horizontal or vertical
CVPixelBufferRef vImageRotateAndReflectPixelBuffer(CVPixelBufferRef sourcePixelBuffer,
                                                   uint8_t rotationConstant,
                                                   BOOL reflect,
                                                   BOOL horizontal);

/// Crop by vImage
/// @param sourcePixelBuffer sourcePixelBuffer
/// @param croppingRect croppingRect
CVPixelBufferRef vImageCropPixelBuffer(CVPixelBufferRef sourcePixelBuffer,
                                       CGRect croppingRect);

@end
