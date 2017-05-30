//
//  RTMPPusher.h
//  RtmpPushiOS
//
//  Created by 姚伟聪 on 2017/5/28.
//  Copyright © 2017年 姚伟聪. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoFrame.h"

@interface RTMPPusher : NSObject


- (instancetype)initWithUrl:(NSString *)url;

- (void)initPusher;

- (void)sendVideoHeader:(VideoFrame *)frame;

- (void)sendVideo:(VideoFrame *)frame;

@end
