//
//  RCRTCAudioRecordFile.m
//  RCRTCAudioMix
//
//  Created by huan xu on 2021/10/27.
//

#import "RCRTCAudioRecordFile.h"

#undef  FStatus
#define FStatus(status, errString) NSAssert(noErr == status, @"File err -> %@, code: %ld", errString, (signed long)status);

@interface RCRTCAudioRecordFile()

@property(nonatomic, copy) NSString * path;
@property(nonatomic, assign) AudioFileTypeID audioFileType;
@property(nonatomic, assign) AudioFormatID   audioFormatID;

@property(nonatomic) AudioStreamBasicDescription formatDescription;
@property(nonatomic) ExtAudioFileRef recordFileRef;

@end

@implementation RCRTCAudioRecordFile

- (instancetype)initWithPath:(NSString *)path
               audioFileType:(AudioFileTypeID)audioFileType
               audioFormatID:(AudioFormatID)audioFormatID
           formatDescription:(AudioStreamBasicDescription)formatDescription{
    if (self = [super init]) {
        self.path = path;
        self.audioFileType = audioFileType;
        self.audioFormatID = audioFormatID;
        self.formatDescription = formatDescription;
    }
    return self;
}

- (void)openFile
{
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:self.path];
    
    AudioStreamBasicDescription recFileFormat = {0};
    recFileFormat.mFormatID         = self.audioFormatID;
    recFileFormat.mChannelsPerFrame = self.formatDescription.mChannelsPerFrame;
    
    
    UInt32 size = sizeof(recFileFormat);
    FStatus(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &recFileFormat), @"Audio format get property");

    FStatus(ExtAudioFileCreateWithURL(url, self.audioFileType, &recFileFormat, NULL, kAudioFileFlags_EraseFile, &_recordFileRef), @"Create recfile err");
    
    FStatus(ExtAudioFileSetProperty(_recordFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(_formatDescription), &_formatDescription), @"Set record format");
    
//    [url CFrelease];
    
}

- (void)closeFile
{
    ExtAudioFileDispose(_recordFileRef);
    _recordFileRef = NULL;
}

- (OSStatus)writeAsyncWithBufferList:(AudioBufferList *)bufferList inNumberFrames:(UInt32)inNumberFrames
{
    return ExtAudioFileWriteAsync(_recordFileRef, inNumberFrames, bufferList);
}


@end
