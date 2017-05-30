//
//  VideoEncoder.h
//  RtmpPushiOS
//
//  Created by 姚伟聪 on 2017/5/26.
//  Copyright © 2017年 姚伟聪. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
@class VideoFrame;
@protocol VideoDelegate <NSObject>

- (void)videoEncoderCallback:(VideoFrame *)data;

@end

@interface VideoEncoder : NSObject

@property (nonatomic , weak) id<VideoDelegate> delegate;
    
- (void)setEncoderWidth:(int)width height:(int)height;

- (void)startEncoding;

- (void)stopEncoding;

- (void)encoder:(CMSampleBufferRef)sampleBuffer;


@end
