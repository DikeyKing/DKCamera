//
//  AREImageCroper.m
//  MMCameraDemo
//
//  Created by Dikey on 2019/12/23.
//  Copyright © 2019 dikey. All rights reserved.
//

#import "DKImageConverter.h"
#import <CoreImage/CoreImage.h>
#import <Accelerate/Accelerate.h>

@implementation DKImageConverter

void assertCropAndScaleValid(CVPixelBufferRef pixelBuffer, CGRect cropRect, CGSize scaleSize)
{
    CGFloat originalWidth = (CGFloat)CVPixelBufferGetWidth(pixelBuffer);
    CGFloat originalHeight = (CGFloat)CVPixelBufferGetHeight(pixelBuffer);
    
    assert(CGRectContainsRect(CGRectMake(0, 0, originalWidth, originalHeight), cropRect));
    assert(scaleSize.width > 0 && scaleSize.height > 0);
}

CVPixelBufferRef createCroppedPixelBufferCoreImage(CVPixelBufferRef pixelBuffer,
                                                                 int orientation,
                                                                 CGRect cropRect,
                                                                 CGSize scaleSize)
{
    return createCroppedPixelBufferCoreImageWithContext(pixelBuffer, orientation ,cropRect, scaleSize,  [CIContext context]);
}

CVPixelBufferRef createCroppedPixelBufferCoreImageWithContext(CVPixelBufferRef pixelBuffer,
                                                   int orientation,
                                                   CGRect cropRect,
                                                   CGSize scaleSize,
                                                   CIContext *context)
{
    assertCropAndScaleValid(pixelBuffer, cropRect, scaleSize);
    
    // 声明 CIImage
    CIImage *image = [CIImage imageWithCVImageBuffer:pixelBuffer];
    
    size_t originHeight = CVPixelBufferGetHeight(pixelBuffer);
    
    CGRect realCropRect =  CGRectMake(cropRect.origin.x, originHeight -  cropRect.size.height - cropRect.origin.y , cropRect.size.width , cropRect.size.height);
    
//    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();

    //裁剪
    image = [image imageByCroppingToRect:realCropRect];
    CGFloat scaleX = scaleSize.width / CGRectGetWidth(image.extent);
    CGFloat scaleY = scaleSize.height / CGRectGetHeight(image.extent);
    
    // 然后缩放
    image = [image imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];
    
    // Due to the way [CIContext:render:toCVPixelBuffer] works, we need to translate the image so the cropped section is at the origin
    image = [image imageByApplyingTransform:CGAffineTransformMakeTranslation(-image.extent.origin.x, -image.extent.origin.y)];
    
    // 最后旋转
    if (orientation > 0) {
        image = [image imageByApplyingOrientation:orientation];
        //        CIImage *image1 = [image imageByApplyingOrientation:1];
        //        CIImage *image2 = [image imageByApplyingOrientation:2]; // 镜像
        //        CIImage *image3 = [image imageByApplyingOrientation:3]; // 180度
        //        CIImage *image4 = [image imageByApplyingOrientation:4]; // 镜像
        //        CIImage *image5 = [image imageByApplyingOrientation:5]; // 旋转+镜像
        //        CIImage *image6 = [image imageByApplyingOrientation:6]; // 正确
        //        CIImage *image7 = [image imageByApplyingOrientation:7]; // 7
        //        CIImage *image8 = [image imageByApplyingOrientation:8]; // 7
    }
    
    CVPixelBufferRef output = NULL;
    
    CVPixelBufferCreate(nil,
                        CGRectGetWidth(image.extent),
                        CGRectGetHeight(image.extent),
                        CVPixelBufferGetPixelFormatType(pixelBuffer),
                        nil,
                        &output);
    
    if (output != NULL) {
        [context render:image toCVPixelBuffer:output];

    }
    
    return output;
}

#pragma mark - vImage Convert

CVPixelBufferRef vImageConvertPixelBuffer(CVPixelBufferRef sourcePixelBuffer,
                                          CGRect croppingRect,
                                          CGSize scaledSize)
{
    OSType inputPixelFormat = CVPixelBufferGetPixelFormatType(sourcePixelBuffer);
    
    //Check if Color Space is Supported
    assert(inputPixelFormat == kCVPixelFormatType_32BGRA
           || inputPixelFormat == kCVPixelFormatType_32ABGR
           || inputPixelFormat == kCVPixelFormatType_32ARGB
           || inputPixelFormat == kCVPixelFormatType_32RGBA);

    // Check Rect
    assertCropAndScaleValid(sourcePixelBuffer, croppingRect, scaledSize);

    if (CVPixelBufferLockBaseAddress(sourcePixelBuffer, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess) {
        NSLog(@"Could not lock base address");
        return nil;
    }

    void *sourceData = CVPixelBufferGetBaseAddress(sourcePixelBuffer);
    if (sourceData == NULL) {
        NSLog(@"Error: could not get pixel buffer base address");
        CVPixelBufferUnlockBaseAddress(sourcePixelBuffer, kCVPixelBufferLock_ReadOnly);
        return nil;
    }
    
    size_t sourceBytesPerRow = CVPixelBufferGetBytesPerRow(sourcePixelBuffer);
    size_t offset = CGRectGetMinY(croppingRect) * sourceBytesPerRow + CGRectGetMinX(croppingRect) * 4;

    // Crop
    vImage_Buffer croppedvImageBuffer = {
        .data = ((char *)sourceData) + offset,
        .height = (vImagePixelCount)CGRectGetHeight(croppingRect),
        .width = (vImagePixelCount)CGRectGetWidth(croppingRect),
        .rowBytes = sourceBytesPerRow
    };

    size_t scaledBytesPerRow = scaledSize.width * 4;
    void *scaledData = malloc(scaledSize.height * scaledBytesPerRow);
    if (scaledData == NULL) {
        NSLog(@"Error: out of memory");
        CVPixelBufferUnlockBaseAddress(sourcePixelBuffer, kCVPixelBufferLock_ReadOnly);
        return nil;
    }

    // Scale
    vImage_Buffer scaledvImageBuffer = {
        .data = scaledData,
        .height = (vImagePixelCount)scaledSize.height,
        .width = (vImagePixelCount)scaledSize.width,
        .rowBytes = scaledBytesPerRow
    };

    /* The ARGB8888, ARGB16U, ARGB16S and ARGBFFFF functions work equally well on
     * other channel orderings of 4-channel images, such as RGBA or BGRA.*/
    vImage_Error error = vImageScale_ARGB8888(&croppedvImageBuffer, &scaledvImageBuffer, nil, 0);
    CVPixelBufferUnlockBaseAddress(sourcePixelBuffer, kCVPixelBufferLock_ReadOnly);

    if (error != kvImageNoError) {
        NSLog(@"Error: %ld", error);
        free(scaledData);
        return nil;
    }
    
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(sourcePixelBuffer);
    CVPixelBufferRef outputPixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreateWithBytes(nil, scaledSize.width, scaledSize.height, pixelFormat, scaledData, scaledBytesPerRow, pixelBufferReleaseCallBack, nil, nil, &outputPixelBuffer);

    if (status != kCVReturnSuccess) {
        NSLog(@"Error: could not create new pixel buffer");
        free(scaledData);
        return nil;
    }

    return outputPixelBuffer;
}

CVPixelBufferRef vImageRotatePixelBuffer(CVPixelBufferRef sourcePixelBuffer, uint8_t rotationConstant)
{
    return [DKImageConverter vImageRotateBuffer:sourcePixelBuffer withConstant:rotationConstant reflect:NO horizontal:NO];
}


CVPixelBufferRef vImageRotateAndReflectPixelBuffer(CVPixelBufferRef sourcePixelBuffer, uint8_t rotationConstant, BOOL reflect, BOOL horizontal)
{
    return [DKImageConverter vImageRotateBuffer:sourcePixelBuffer withConstant:rotationConstant reflect:reflect horizontal:horizontal];
}

+ (CVPixelBufferRef)vImageRotateBuffer:(CVImageBufferRef)imageBuffer
                            withConstant:(uint8_t)rotationConstant
                                 reflect:(BOOL)reflect
                              horizontal:(BOOL)horizontal
{
    //    CVImageBufferRef imageBuffer        = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferRetain(imageBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    OSType pixelFormatType              = CVPixelBufferGetPixelFormatType(imageBuffer);
    //    NSAssert(pixelFormatType == kCVPixelFormatType_32ARGB, @"Code works only with 32ARGB format. Test/adapt for other formats!");
    size_t kAlignment_32ARGB      = 32;
    size_t kBytesPerPixel_32ARGB  = 4;
    size_t bytesPerRow                  = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width                        = CVPixelBufferGetWidth(imageBuffer);
    size_t height                       = CVPixelBufferGetHeight(imageBuffer);
    BOOL rotatePerpendicular            = (rotationConstant == 1) || (rotationConstant == 3); // Use enumeration values here
    size_t outWidth               = rotatePerpendicular ? height : width;
    size_t outHeight              = rotatePerpendicular ? width  : height;
    size_t bytesPerRowOut               = kBytesPerPixel_32ARGB * ceil(outWidth * 1.0 / kAlignment_32ARGB) * kAlignment_32ARGB;
    size_t dstSize                = bytesPerRowOut * outHeight * sizeof(unsigned char);
    void *srcBuff                       = CVPixelBufferGetBaseAddress(imageBuffer);
    unsigned char *dstBuff              = (unsigned char *)malloc(dstSize);
    vImage_Buffer inbuff                = {srcBuff, height, width, bytesPerRow};
    vImage_Buffer outbuff               = {dstBuff, outHeight, outWidth, bytesPerRowOut};
    uint8_t bgColor[4]                  = {0, 0, 0, 0};
    vImage_Error err                    = vImageRotate90_ARGB8888(&inbuff, &outbuff, rotationConstant, bgColor, 0);
    if (err != kvImageNoError){
        NSLog(@"%ld", err);
    }
    
    if (reflect) {
        vImage_Error ret;
        // 省略
        if (horizontal) {
            // 水平镜像
            ret = vImageHorizontalReflect_ARGB8888(&inbuff, &outbuff, kvImageHighQualityResampling);
        } else {
            // 垂直镜像
            ret = vImageVerticalReflect_ARGB8888(&inbuff, &outbuff, kvImageHighQualityResampling);
        }
        if (ret != kvImageNoError) {
            NSLog(@"insight_rotateBuffer ret error");
        }
    }

    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    CVPixelBufferRelease(imageBuffer);
    CVPixelBufferRef rotatedBuffer      = NULL;
    CVPixelBufferCreateWithBytes(NULL,
                                 outWidth,
                                 outHeight,
                                 pixelFormatType,
                                 outbuff.data,
                                 bytesPerRowOut,
                                 pixelBufferReleaseCallBack,
                                 NULL,
                                 NULL,
                                 &rotatedBuffer);
    return rotatedBuffer;
}

+ (CVPixelBufferRef)insight_rotateBuffer:(CVImageBufferRef)imageBuffer
                            withConstant:(uint8_t)rotationConstant
{
    return [DKImageConverter vImageRotateBuffer:imageBuffer withConstant:rotationConstant reflect:NO horizontal:NO];
}

#pragma mark - Release

void pixelBufferReleaseCallBack(void *releaseRefCon, const void *baseAddress) {
    if (baseAddress != NULL) {
        free((void *)baseAddress);
    }
}

#pragma mark - debug

CVPixelBufferRef vImageCropPixelBuffer(CVPixelBufferRef sourcePixelBuffer,
                                          CGRect croppingRect)
{
    OSType inputPixelFormat = CVPixelBufferGetPixelFormatType(sourcePixelBuffer);
    
    //Check if Color Space is Supported
    assert(inputPixelFormat == kCVPixelFormatType_32BGRA
           || inputPixelFormat == kCVPixelFormatType_32ABGR
           || inputPixelFormat == kCVPixelFormatType_32ARGB
           || inputPixelFormat == kCVPixelFormatType_32RGBA);

    if (CVPixelBufferLockBaseAddress(sourcePixelBuffer, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess) {
        NSLog(@"Could not lock base address");
        return nil;
    }

    void *sourceData = CVPixelBufferGetBaseAddress(sourcePixelBuffer);
    if (sourceData == NULL) {
        NSLog(@"Error: could not get pixel buffer base address");
        CVPixelBufferUnlockBaseAddress(sourcePixelBuffer, kCVPixelBufferLock_ReadOnly);
        return nil;
    }
    
    size_t sourceBytesPerRow = CVPixelBufferGetBytesPerRow(sourcePixelBuffer);
    size_t offset = CGRectGetMinY(croppingRect) * sourceBytesPerRow + CGRectGetMinX(croppingRect) * 4;

    // Crop
    vImage_Buffer croppedvImageBuffer = {
        .data = ((char *)sourceData) + offset,
        .height = (vImagePixelCount)CGRectGetHeight(croppingRect),
        .width = (vImagePixelCount)CGRectGetWidth(croppingRect),
        .rowBytes = sourceBytesPerRow
    };

    /* The ARGB8888, ARGB16U, ARGB16S and ARGBFFFF functions work equally well on
     * other channel orderings of 4-channel images, such as RGBA or BGRA.*/
    CVPixelBufferUnlockBaseAddress(sourcePixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(sourcePixelBuffer);
    CVPixelBufferRef outputPixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreateWithBytes(nil, croppingRect.size.width, croppingRect.size.height, pixelFormat, croppedvImageBuffer.data , croppedvImageBuffer.rowBytes, pixelBufferReleaseCallBack, nil, nil, &outputPixelBuffer);

    if (status != kCVReturnSuccess) {
        NSLog(@"Error: could not create new pixel buffer");
        free(sourceData);
        return nil;
    }

    return outputPixelBuffer;
}

@end
