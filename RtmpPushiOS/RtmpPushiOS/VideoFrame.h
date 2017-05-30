//
//  VideoFrame.h
//  RtmpPushiOS
//
//  Created by 姚伟聪 on 2017/5/29.
//  Copyright © 2017年 姚伟聪. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VideoFrame : NSObject

@property (nonatomic, assign,) uint64_t timestamp;
@property (nonatomic, strong) NSData *data;
    ///< flv或者rtmp包头
@property (nonatomic, strong) NSData *header;
    
@property (nonatomic , assign,getter=isKeyFrame) BOOL keyFrame;
@property (nonatomic, strong) NSData *sps;
@property (nonatomic, strong) NSData *pps;
    
@end
