//
//  RCRTCAudioGraph.m
//  RCRTCAudioMix
//
//  Created by huan xu on 2021/10/27.
//

#import "RCRTCAudioGraph.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#undef  CStatus
#define CStatus(status, errString) NSAssert(noErr == status, @"%@, code: %ld", errString, (signed long)status);

@implementation RCRTCAudioGraph
{
    AUGraph _processingGraph;
    AudioUnit _ioUnit;
    AudioUnit _mixUnit;
    CGFloat _graphSampleRate;
    
    BOOL _isRunning;
}
#pragma mark - Helper

///// 初始化组件
//- (AUNode)setupNodeWithComponentDescription:(AudioComponentDescription)desc
//                                       unit:(AudioUnit *)unit
//{
//    AUNode node;
//    // 添加node并取得unit
//    CStatus(AUGraphAddNode(_coreGraph, &desc, &node), @"couldn't add remote io node");
//    CStatus(AUGraphNodeInfo(_coreGraph, node, NULL, unit), @"couldn't get remote io unit from node");
//    return node;
//}

static void CheckStatus(OSStatus status, NSString *message, BOOL fatal)
{
    if(status != noErr) {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';
        if(isprint(fourCC[0]) && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[3]))
            NSLog(@"%@:%s",message,fourCC);
        else
            NSLog(@"%@:%d",message,(int)status);
        if(fatal)
            exit(-1);
      }
}

- (AudioComponentDescription)ioUnitDesc{
    AudioComponentDescription desc;
    desc.componentType          = kAudioUnitType_Output;
    desc.componentSubType       = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer  = kAudioUnitManufacturer_Apple;
    desc.componentFlags         = 0;
    desc.componentFlagsMask     = 0;
    return desc;
}

- (AudioComponentDescription)mixUnitDesc{
    AudioComponentDescription desc;
    desc.componentType          = kAudioUnitType_Mixer;
    desc.componentSubType       = kAudioUnitSubType_MultiChannelMixer;
    desc.componentManufacturer  = kAudioUnitManufacturer_Apple;
    desc.componentFlags         = 0;
    desc.componentFlagsMask     = 0;
    return desc;
}

- (void)configUnit{
    
    //第一步初始化 graph
    OSStatus status = noErr;
    status = NewAUGraph(&_processingGraph);
    CheckStatus(status, @"NewAUGraph failed", YES);
    
    status = AUGraphOpen(_processingGraph);
    CheckStatus(status, @"AUGraphOpen failed", YES);
    
    
    //创建 ioUnit
    AudioComponentDescription ioDesc = [self ioUnitDesc];
    AUNode ioNode;
    status = AUGraphAddNode(_processingGraph,
                            &ioDesc,
                            &ioNode);
    CheckStatus(status, @"ioNode add failed", YES);

    status = AUGraphNodeInfo(_processingGraph,
                             ioNode,
                             NULL,
                             &_ioUnit);
    CheckStatus(status, @"io Unit create failed", YES);
    
    //打开输入/输出
    [self ioUnitconnect];
    
    //设置io 的输入/输出流格式
    [self setStreamFormatWithAudioUnit:_ioUnit asbd:[self ioStreamFormat]];
    
    //创建 mixUnit
    AudioComponentDescription mixDesc = [self mixUnitDesc];
    AUNode mixNode;
    status = AUGraphAddNode(_processingGraph,
                            &mixDesc,
                            &mixNode);
    CheckStatus(status, @"mixNode add failed", YES);

    status = AUGraphNodeInfo(_processingGraph,
                             mixNode,
                             NULL,
                             &_mixUnit);
    CheckStatus(status, @"mix Unit create failed", YES);
    
    
    
    AudioStreamBasicDescription outMixASBD = [self ioStreamFormat];
    status = AudioUnitSetProperty(_mixUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  &outMixASBD,
                                  sizeof(outMixASBD));
    
    
    
    
//    [self setStreamFormatWithAudioUnit:_mixUnit asbd:[self ]]
    
    //连接
//    status = AUGraphConnectNodeInput(_processingGraph, ioNode, 1, ioNode, 0);
//    CheckStatus(status, @"连接失败", YES);
//
//    status = AUGraphInitialize(_processingGraph);
//    CheckStatus(status, @"AUGraphInitialize failed", YES);
    
}

- (void)ioUnitconnect{
    OSStatus status = noErr;
    //将 remoteIO Unit 的输出端连接扬声器
    UInt32 busZero = 0;
    UInt32 flag = 1;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  busZero,
                                  &flag,
                                  sizeof(flag));
    CheckStatus(status, @"Could not Connect To Speaker", YES);
    //将 remoteIO Unit 的输入端连接麦克风
    UInt32 busOne = 1;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  busOne,
                                  &flag,
                                  sizeof(flag));
    CheckStatus(status, @"Could not Connect To Mic", YES);
}

//- (void)setMixUnit{
//    OSStatus status = noErr;
//    UInt32 propertySize = sizeof(AudioStreamBasicDescription);
////    status = AudioUnitSetProperty(_mixUnit, , <#AudioUnitScope inScope#>, <#AudioUnitElement inElement#>, <#const void * _Nullable inData#>, <#UInt32 inDataSize#>)
//}



- (AudioStreamBasicDescription)ioStreamFormat{
    AudioStreamBasicDescription ioStreamFormat;
    UInt32 bytesPerSample = sizeof(SInt32);
    
    ioStreamFormat.mFormatID         = kAudioFormatLinearPCM;
    ioStreamFormat.mFormatFlags      = kAudioFormatFlagsCanonical;
    ioStreamFormat.mBytesPerPacket   = bytesPerSample;
    ioStreamFormat.mFramesPerPacket  = 1;
    ioStreamFormat.mBytesPerFrame    = bytesPerSample;
    ioStreamFormat.mChannelsPerFrame = 2;
    ioStreamFormat.mBitsPerChannel   = 16;
    ioStreamFormat.mSampleRate       = _graphSampleRate;
    return ioStreamFormat;
}

- (AudioStreamBasicDescription)mixStreamFormat{
    AudioStreamBasicDescription mixStreamFormat;
    UInt32 bytesPerSample = sizeof(SInt32);
    
    mixStreamFormat.mFormatID         = kAudioFormatLinearPCM;
    mixStreamFormat.mFormatFlags      = kAudioFormatFlagsCanonical;
    mixStreamFormat.mBytesPerPacket   = bytesPerSample;
    mixStreamFormat.mFramesPerPacket  = 1;
    mixStreamFormat.mBytesPerFrame    = bytesPerSample;
    mixStreamFormat.mChannelsPerFrame = 2;
    mixStreamFormat.mBitsPerChannel   = 16;
    mixStreamFormat.mSampleRate       = _graphSampleRate;
    return mixStreamFormat;
}



//设置输出音频流格式
- (void)setStreamFormatWithAudioUnit:(AudioUnit)audioUnit
                                asbd:(AudioStreamBasicDescription)asbd{
    
    OSStatus status = noErr;
    //输出流格式
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  1,
                                  &asbd,
                                  sizeof(asbd));
    CheckStatus(status, @"ioUnit output StreamFormat set failed", YES);
    //输入流格式
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &asbd,
                                  sizeof(asbd));
    
    CheckStatus(status, @"ioUnit input StreamFormat set failed", YES);
    
}



@end
