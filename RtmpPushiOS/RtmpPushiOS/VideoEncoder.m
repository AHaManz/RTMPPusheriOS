//
//  VideoEncoder.m
//  RtmpPushiOS
//
//  Created by 姚伟聪 on 2017/5/26.
//  Copyright © 2017年 姚伟聪. All rights reserved.
//

#import "VideoEncoder.h"
#import "VideoFrame.h"

@interface VideoEncoder (){

    VTCompressionSessionRef encodingSession;
    NSData *sps;
    NSData *pps;
}

@property(nonatomic, assign) int width;
@property(nonatomic, assign) int height;
@property(nonatomic, assign) int frameCount;
@property(nonatomic, assign, getter=isStartEncoding) BOOL startEncoding;
@property (nonatomic , assign , getter=isKeyFrame) BOOL keyFrame;
    
@end

@implementation VideoEncoder

- (void)setEncoderWidth:(int)width height:(int)height{
    _width = width;
    _height = height;
    OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, outputCallback, (__bridge void *)(self),&encodingSession);
    
    if (status != 0) {
        NSLog(@"unable to create session");
        return;
    }
    
    VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_RealTime,kCFBooleanTrue);
    VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    
    //keyFrame interval（关键帧间隔）
    int frameInterval = 10;
    CFNumberRef frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
    VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
    
    //期望帧率
    int fps = 30;
    CFNumberRef fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
    VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
    
    //码率上限，单位bps
    int bitRate = width * height * 3 * 4 * 8;
    CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
    VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
    
    //码率均值,单位byte
    int bitRateLimit = width * height * 3 * 4;
    CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRateLimit);
    VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
    VTCompressionSessionPrepareToEncodeFrames(encodingSession);
}

- (void)startEncoding{
    
    
    _startEncoding = YES;
}

- (void)stopEncoding{

    _startEncoding = NO;
}

- (void)encoder:(CMSampleBufferRef)sampleBuffer{
    if (_startEncoding) {
        _frameCount++;
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CMTime time = CMTimeMake(_frameCount, 1000);
        VTEncodeInfoFlags flags;
        
        OSStatus statusCode = VTCompressionSessionEncodeFrame(encodingSession, imageBuffer, time, kCMTimeInvalid, NULL, NULL, &flags);
        
        if (statusCode != noErr) {
            NSLog(@"encoder failed");
            VTCompressionSessionInvalidate(encodingSession);
        }

    }
}

void outputCallback(void *VTref,void *VTFrameRef,
                    OSStatus status,VTEncodeInfoFlags infoFlags,CMSampleBufferRef sampleBuffer){
    NSLog(@"encode success");
    
    if (!sampleBuffer) {
        return;
    }
    
    CFArrayRef arrary = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (!arrary) {
        return;
    }
    
    CFDictionaryRef dic = CFArrayGetValueAtIndex(arrary, 0);
    if (!dic) {
        return;
    }
    
    BOOL keyFrame = !CFDictionaryContainsKey(dic, kCMSampleAttachmentKey_NotSync);
    uint64_t timeStamp = [(__bridge_transfer NSNumber *)(VTFrameRef) longLongValue];
    
    VideoEncoder *encoder = (__bridge VideoEncoder *)(VTref);
    
    if (status != noErr) {
        return;
    }
    
    if (keyFrame && !encoder->sps) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        
        if (statusCode == noErr) {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            
            if (statusCode == noErr) {
                encoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            VideoFrame *frame = [VideoFrame new];
            frame.timestamp = timeStamp;
            frame.keyFrame = keyFrame;
            frame.sps = encoder->sps;
            frame.pps = encoder->pps;
            frame.data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            
            if ([encoder.delegate respondsToSelector:@selector(videoEncoderCallback:)]) {
                [encoder.delegate videoEncoderCallback:frame];
            }
            
            bufferOffset += AVCCHeaderLength + NALUnitLength;
            
        }
    }


}



@end
