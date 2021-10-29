//
//  ViewController.m
//  RCRTCAudioMix
//
//  Created by huan xu on 2021/10/26.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "RCRTCAudioReader.h"


@interface ViewController ()<RCRTCAudioReaderDelegate>
@property (nonatomic, strong)RCRTCAudioReader *reader;
@property (nonatomic, strong)NSTimer *progressTimer;
@end

@implementation ViewController
{
    float _graphSampleRate;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.reader.ktvMode = RCRTCAudioKTVMode_Stereo;
    [self.reader start];
    
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSLog(@"播放进度:%@",@([self.reader getCurrentTime]));
    }];
}

#pragma mark - RCRTCAudioReaderDelegate
- (void)onFinished{
    [self.progressTimer invalidate];
    self.progressTimer = nil;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    if (self.reader.ktvMode == RCRTCAudioKTVMode_Left) {
        self.reader.ktvMode = RCRTCAudioKTVMode_Right;
    }else{
        self.reader.ktvMode = RCRTCAudioKTVMode_Left;
    }
}


- (AudioStreamBasicDescription)ioStreamFormat{
    AudioStreamBasicDescription ioStreamFormat;
    ioStreamFormat.mSampleRate       = 48000;
    ioStreamFormat.mFormatID         = kAudioFormatLinearPCM;
    ioStreamFormat.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    ioStreamFormat.mFramesPerPacket  = 1;
    ioStreamFormat.mChannelsPerFrame = 2;//双声道
    ioStreamFormat.mBitsPerChannel   = 16;
    ioStreamFormat.mBytesPerFrame    = (ioStreamFormat.mBitsPerChannel * ioStreamFormat.mChannelsPerFrame) / 8;
    ioStreamFormat.mBytesPerPacket   = ioStreamFormat.mBytesPerFrame;
    
//    ioStreamFormat.mSampleRate       = 44100;
//    ioStreamFormat.mFormatID         = kAudioFormatLinearPCM;
//    ioStreamFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger;
//    ioStreamFormat.mBytesPerPacket   = 2;
//    ioStreamFormat.mFramesPerPacket  = 1;
//    ioStreamFormat.mBytesPerFrame    = 2;
//    ioStreamFormat.mChannelsPerFrame = 2;
//    ioStreamFormat.mBitsPerChannel   = 16;
    
    return ioStreamFormat;
}

- (RCRTCAudioReader *)reader{
    if (!_reader) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"小哪吒" ofType:@"mp3"];
        path = [[NSBundle mainBundle] pathForResource:@"love_story" ofType:@"mp4"];
        _reader = [[RCRTCAudioReader alloc] initWithPath:path outputFormat:[self ioStreamFormat]];
    }
    return _reader;
}

@end
