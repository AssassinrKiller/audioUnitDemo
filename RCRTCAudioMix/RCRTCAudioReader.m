//
//  RCRTCAudioReader.m
//  RCRTCAudioMix
//
//  Created by huan xu on 2021/10/28.
//

#import "RCRTCAudioReader.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <assert.h>

#define OUTPUT_BUS (0)
const uint32_t CONST_BUFFER_SIZE = 0x10000;

@interface RCRTCAudioReader()


@end

@implementation RCRTCAudioReader
{
    ExtAudioFileRef exAudioFile;
    AudioStreamBasicDescription audioFileFormat;
    AudioStreamBasicDescription outputFormat;
    
    SInt64 readedFrame; // 已读的frame数量
    UInt64 totalFrame; // 总的Frame数量
    
    AudioUnit audioUnit;
    AudioBufferList *buffList;
}

- (instancetype)initWithPath:(NSString *)path
                outputFormat:(AudioStreamBasicDescription)format{
    if (self = [super init]) {
        
        outputFormat = format;
        
        [self printAudioFormat:outputFormat];
        
        // Extend Audio File
        NSURL *url = [NSURL fileURLWithPath:path];
        OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)url, &exAudioFile);
        CheckError(status, "打开文件失败");
        
        //读取音频流格式
        UInt32 size = sizeof(AudioStreamBasicDescription);
        status = ExtAudioFileGetProperty(exAudioFile,
                                         kExtAudioFileProperty_FileDataFormat,
                                         &size,
                                         &audioFileFormat);
        CheckError(status, "ExtAudioFileGetProperty  error");
        
        [self printAudioFormat:audioFileFormat];
        //设置输出音频格式
        status = ExtAudioFileSetProperty(exAudioFile,
                                         kExtAudioFileProperty_ClientDataFormat,
                                         size,
                                         &outputFormat);
        CheckError(status, "ExtAudioFileSetProperty error");

        //初始化不能太前，如果未设置好输入输出格式，获取的总frame数不准确
        size = sizeof(totalFrame);
        status = ExtAudioFileGetProperty(exAudioFile,
                                         kExtAudioFileProperty_FileLengthFrames,
                                         &size,
                                         &totalFrame);
        
        [self setupAudioUnit];
        
    }
    return self;
}

- (AudioStreamBasicDescription)audioFileFormat{
    return audioFileFormat;
}

- (void)start {
    AudioOutputUnitStart(audioUnit);
}

- (double)getCurrentTime {
    Float64 timeInterval = (readedFrame * 1.0) / totalFrame;
    return timeInterval;
}

- (void)setupAudioUnit {
    //prepare
    NSError *error = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setPreferredSampleRate:audioFileFormat.mSampleRate error:&error];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
    [audioSession setActive:YES error: &error];
    if (error) NSLog(@"AVAudioSession error:%@",error);
    
    // BUFFER
    buffList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = 1;
    if (outputFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
        buffList->mNumberBuffers = 2;
    }
    for (int i = 0; i < buffList->mNumberBuffers; i++) {
        buffList->mBuffers[i].mNumberChannels = 1;
        buffList->mBuffers[i].mDataByteSize = CONST_BUFFER_SIZE;
        buffList->mBuffers[i].mData = malloc(CONST_BUFFER_SIZE);
    }
    
    OSStatus status = noErr;
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    CheckError(status, "AudioComponentInstanceNew error");
    
    //initAudioProperty
    UInt32 flag = 1;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  OUTPUT_BUS,
                                  &flag,
                                  sizeof(flag));
    CheckError(status, "打开扬声器失败");
    
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    CheckError(status, "设置播放流格式失败");
    
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &playCallback,
                                  sizeof(playCallback));
    NSAssert(!status, @"AudioUnitSetProperty error");
    status = AudioUnitInitialize(audioUnit);
    NSAssert(!status, @"AudioUnitInitialize error");
}

void fillToBuffer(AudioBufferList *ioData, AudioBufferList *sourceBuffer, NSInteger ktvMode)
{
    void*  sourceData = sourceBuffer->mBuffers[0].mData;
    UInt32 sourceDataSize = sourceBuffer->mBuffers[0].mDataByteSize;
    
    void*  targetData = ioData->mBuffers[0].mData;
    UInt32 targetDataSize = ioData->mBuffers[0].mDataByteSize;
    
    if (ktvMode == RCRTCAudioKTVMode_Left) {
        for (UInt32 offset = 0; offset < sourceDataSize; offset+=4) {
            UInt32 left_start = offset;
            UInt32 right_start = offset + 2;
            memcpy(targetData + left_start, sourceData + left_start, 2);
            memcpy(targetData + right_start, sourceData + left_start, 2);
        }
    }
    else if (ktvMode == RCRTCAudioKTVMode_Right) {
        for (UInt32 offset = 0; offset < sourceDataSize; offset+=4) {
            UInt32 left_start = offset;
            UInt32 right_start = offset + 2;
            memcpy(targetData + left_start, sourceData + right_start, 2);
            memcpy(targetData + right_start, sourceData + right_start, 2);
        }
    }
    else {
        memcpy(targetData, sourceData, sourceDataSize);
    }
    
    targetDataSize = sourceDataSize;
}



OSStatus PlayCallback(void *inRefCon,
                      AudioUnitRenderActionFlags *ioActionFlags,
                      const AudioTimeStamp *inTimeStamp,
                      UInt32 inBusNumber,
                      UInt32 inNumberFrames,
                      AudioBufferList *ioData) {
    
    RCRTCAudioReader *reader = (__bridge RCRTCAudioReader *)inRefCon;
    
    OSStatus status = ExtAudioFileRead(reader->exAudioFile,
                                       &inNumberFrames,
                                       reader->buffList);
    CheckError(status, "ExtAudioFileRead failed");
    
    if (!inNumberFrames) NSLog(@"播放结束");

    //填充数据
    fillToBuffer(ioData, reader->buffList, reader.ktvMode);
    
    //获取进度 mBytesPerFrame = 2，所以是每 2 bytes 一帧
    UInt32 sourceDataSize = reader->buffList->mBuffers[0].mDataByteSize;
    reader->readedFrame += sourceDataSize / reader->outputFormat.mBytesPerFrame;
    
    if (sourceDataSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [reader onFinished];
        });
    }
    return noErr;
}

- (void)onFinished {
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    if (buffList != NULL) {
        if (buffList->mBuffers[0].mData) {
            free(buffList->mBuffers[0].mData);
            buffList->mBuffers[0].mData = NULL;
        }
        free(buffList);
        buffList = NULL;
    }
    if ([self.delegate respondsToSelector:@selector(onFinished)]) {
        [self.delegate onFinished];
    }
}

- (FILE *)pcmFile {
    static FILE *_pcmFile;
    if (!_pcmFile) {
        NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test.pcm"];
        _pcmFile = fopen(filePath.UTF8String, "w");
        
    }
    return _pcmFile;
}

- (void)printAudioFormat:(AudioStreamBasicDescription)asbd
{
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("Sample Rate:         %10.0f\n",  asbd.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)asbd.mBitsPerChannel);
    printf("\n");
}

void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    
    char str[20];
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    
    fprintf(stderr, "Error: %s (%s)\n", operation, str);
    
    exit(1);
}

@end
