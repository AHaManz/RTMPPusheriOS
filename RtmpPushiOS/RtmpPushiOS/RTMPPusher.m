//
//  RTMPPusher.m
//  RtmpPushiOS
//
//  Created by 姚伟聪 on 2017/5/28.
//  Copyright © 2017年 姚伟聪. All rights reserved.
//

#import "RTMPPusher.h"
#import "rtmp.h"

#define RTMP_HEAD_SIZE  (sizeof(RTMPPacket)+RTMP_MAX_HEADER_SIZE)

@interface RTMPPusher (){
    
    RTMP *rtmp;
}
@property (nonatomic , copy) NSString *url;
@property (nonatomic, strong) dispatch_queue_t rtmpSendQueue;
@end

@implementation RTMPPusher

- (instancetype)initWithUrl:(NSString *)url{
    if (self = [super init]) {
        _url = url;
        
        NSLog(@"currentThread pusher %@",[NSThread currentThread]);
    }
    return self;
}
    
- (void)initPusher{
    
        if (rtmp) {
            NSLog(@"不为空");
            return ;
        }
        rtmp = RTMP_Alloc();
        RTMP_Init(rtmp);
        
        if(RTMP_SetupURL(rtmp, (char *)[_url UTF8String]) == 0){
            NSLog(@"setupURL faild");
            return;
        }
        
        /*设置可写,即发布流,这个函数必须在连接前使用,否则无效*/
        RTMP_EnableWrite(rtmp);
        
        if (RTMP_Connect(rtmp, NULL) == 0) {
            NSLog(@"connect faild ");
            return;
        }
        
        if (RTMP_ConnectStream(rtmp, 0) == 0) {
            NSLog(@"connectStream faild");
            RTMP_Close(rtmp);
            RTMP_Free(rtmp);
            return;
        }
        NSLog(@"init success");
   
}

- (void)sendVideoHeader:(VideoFrame *)frame{
    if (!frame) {
        return;
    }
    unsigned char *body = NULL;
    NSInteger iIndex = 0;
    NSInteger rtmpLength = 1024;
    const char *sps = frame.sps.bytes;
    const char *pps = frame.pps.bytes;
    NSInteger spsLength = frame.sps.length;
    NSInteger ppsLength = frame.pps.length;
    
    body = (unsigned char *)malloc(rtmpLength);
    memset(body, 0, rtmpLength);
    
    //tag的头 1 表示keyFrame 7表示AVC
    body[iIndex++] = 0x17;
    //AVCPackType 0 表示 AVC sequence header
    body[iIndex++] = 0x00;
    //CompositionTime标准协议上写的是 AVCPackType 如果不等于1就全为0（但这里都等于0不知道为什么）
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    //AVCDecoderConfigurationRecord 有sps pps等信息，再发送数据前必须先发送给服务器
    body[iIndex++] = 0x01;
    body[iIndex++] = sps[1];
    body[iIndex++] = sps[2];
    body[iIndex++] = sps[3];
    body[iIndex++] = 0xff;
    
    /*sps*/
    body[iIndex++] = 0xe1;
    body[iIndex++] = (spsLength >> 8) & 0xff;
    body[iIndex++] = spsLength & 0xff;
    memcpy(&body[iIndex], sps, spsLength);
    iIndex += spsLength;
    
    /*pps*/
    body[iIndex++] = 0x01;
    body[iIndex++] = (ppsLength >> 8) & 0xff;
    body[iIndex++] = (ppsLength) & 0xff;
    memcpy(&body[iIndex], pps, ppsLength);
    iIndex += ppsLength;
    
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:iIndex timestamp:0];
    
    free(body);

}

- (void)sendVideo:(VideoFrame *)frame{
    
    NSInteger iIndex = 0;
    //加上tagData前9byte信息数据
    NSInteger rtmpLength = frame.data.length + 9;
    unsigned char *body = (unsigned char *)malloc(rtmpLength);
    
    if (frame.isKeyFrame) {
        body[iIndex++] = 0x17; //1 IFrame 7 AVC
    }else{
        body[iIndex++] = 0x27; //2 PFrame 7 AVC
    }
    
    body[iIndex++] = 0x01;
    
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    
    body[iIndex++] = (frame.data.length >> 24) & 0xff;
    body[iIndex++] = (frame.data.length >> 16) & 0xff;
    body[iIndex++] = (frame.data.length >>  8) & 0xff;
    body[iIndex++] = (frame.data.length) & 0xff;
    
    memcpy(&body[iIndex], frame.data.bytes, frame.data.length);
    
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:iIndex timestamp:frame.timestamp];
    
    free(body);
}

- (void)sendPacket:(NSInteger)packetType data:(unsigned char *)data size:(NSInteger)size timestamp:(uint64_t)timestamp{
    
    dispatch_async(self.rtmpSendQueue, ^{
        NSInteger rtmpLength = size;
        RTMPPacket *packet = NULL;
        RTMPPacket_Reset(packet);
        RTMPPacket_Alloc(packet, (uint32_t)rtmpLength);
        
        packet->m_nBodySize = (uint32_t)size;
        memcpy(packet->m_body, data, size);
        
        packet->m_hasAbsTimestamp = 0;
        packet->m_packetType = packetType;
        
        if (rtmp) {
            packet->m_nInfoField2 = rtmp->m_stream_id;
        }
        packet->m_nChannel = 0x04;
        packet->m_headerType = RTMP_PACKET_SIZE_LARGE;
        
        if (RTMP_PACKET_TYPE_AUDIO == packetType && size != 4) {
            packet->m_headerType = RTMP_PACKET_SIZE_MEDIUM;
        }
        
        packet->m_nTimeStamp = (uint32_t)timestamp;
        
        if (rtmp && RTMP_IsConnected(rtmp)) {
            
            RTMP_SendPacket(rtmp, packet, 0);
        }

    });
    
}

#pragma mark- 懒加载

- (dispatch_queue_t)rtmpSendQueue{
    if(!_rtmpSendQueue){
        _rtmpSendQueue = dispatch_queue_create("com.RtmpPushiOS", NULL);
    }
    return _rtmpSendQueue;
}
@end
