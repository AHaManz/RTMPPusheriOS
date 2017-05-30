//
//  ViewController.m
//  RtmpPushiOS
//
//  Created by 姚伟聪 on 2017/5/26.
//  Copyright © 2017年 姚伟聪. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "VideoEncoder.h"
#import "RTMPPusher.h"

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate,VideoDelegate>

@property (nonatomic , strong) AVCaptureSession *captureSession;
@property (nonatomic , strong) AVCaptureDeviceInput *captureInput;
@property (nonatomic , strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic , strong) AVCaptureAudioDataOutput *audioDataOutput;
@property (nonatomic , strong) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic, strong) VideoEncoder *videoEncoder;
@property (nonatomic , strong) RTMPPusher *rtmpPusher;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initRTMPPusher];
    [self initCapture];
    [self initEncoder];
    if (self.captureSession) {
        [self.captureSession startRunning];
    }
    
}

- (void)initRTMPPusher{
    self.rtmpPusher = [[RTMPPusher alloc] initWithUrl:@"rtmp://192.168.0.100:1935/rtmplive/room"];
    [self.rtmpPusher initPusher];
}

- (void)initEncoder{
    [self.videoEncoder setEncoderWidth:1280 height:720];
}
- (IBAction)startLive:(UIButton *)sender {
    
    [self.videoEncoder startEncoding];
    
}

- (void)initCapture{
    
    self.captureSession = [[AVCaptureSession alloc] init];
    
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        [self.captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
    }
    
    AVCaptureDevice *backCamera = nil;
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if (camera.position == AVCaptureDevicePositionBack) {
            backCamera = camera;
        }
    }
    
    if (!backCamera) {
        NSLog(@"获取摄像头失败");
        return;
    }
    
    NSError *err = nil;
    self.captureInput = [[AVCaptureDeviceInput alloc]initWithDevice:backCamera error:&err ];
    
    if (err) {
        NSLog(@"摄像头输入初始化失败%@",err);
        return;
    }
    
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    dispatch_queue_t videoCaptureQueue = dispatch_queue_create("videoCaptureQueue", DISPATCH_QUEUE_SERIAL);
    [self.videoDataOutput setSampleBufferDelegate:self queue:videoCaptureQueue];
    //设置输出格式
    self.videoDataOutput.videoSettings = @{(__bridge id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    
    self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    dispatch_queue_t audioCaptureQueue = dispatch_queue_create("audioCaptureQueue", DISPATCH_QUEUE_SERIAL);
    //    [self.audioDataOutput setSampleBufferDelegate:self queue:audioCaptureQueue];
    
    if (![self.captureSession canAddInput:self.captureInput]) {
        NSLog(@"无法添加输入");
        return;
    }
    [self.captureSession addInput:self.captureInput];
    
    if (![self.captureSession canAddOutput:self.videoDataOutput]) {
        
        NSLog(@"无法添加视频输出");
        return;
    }
    [self.captureSession addOutput:self.videoDataOutput];
    
    if (![self.captureSession canAddOutput:self.audioDataOutput]) {
        
        NSLog(@"无法添加音频输出");
        return;
    }
    [self.captureSession addOutput:self.audioDataOutput];
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    
    self.view.layer.masksToBounds = YES;
    self.previewLayer.frame = self.view.layer.bounds;
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- videoDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    
    [self.videoEncoder encoder:sampleBuffer];
    
}

- (void)videoEncoderCallback:(VideoFrame *)frame{
    
    if (frame.sps) {
        [self.rtmpPusher sendVideoHeader:frame];
        return;
    }
    
    [self.rtmpPusher sendVideo:frame];
    
}

- (VideoEncoder *)videoEncoder{
    if (!_videoEncoder) {
        _videoEncoder = [[VideoEncoder alloc] init];
        _videoEncoder.delegate = self;
    }
    return _videoEncoder;
}


@end
