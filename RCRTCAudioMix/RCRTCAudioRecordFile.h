//
//  RCRTCAudioRecordFile.h
//  RCRTCAudioMix
//
//  Created by huan xu on 2021/10/27.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCRTCAudioRecordFile : NSObject

@property(nonatomic, readonly) AudioStreamBasicDescription formatDescription;
@property(nonatomic, readonly) ExtAudioFileRef recordFileRef;
@property(nonatomic, readonly) NSString * path;

- (instancetype)initWithPath:(NSString *)path
               audioFileType:(AudioFileTypeID)audioFileType
               audioFormatID:(AudioFormatID)audioFormatID
           formatDescription:(AudioStreamBasicDescription)formatDescription;

- (void)openFile;
- (void)closeFile;

- (OSStatus)writeAsyncWithBufferList:(AudioBufferList *)bufferList
                      inNumberFrames:(UInt32)inNumberFrames;



@end

NS_ASSUME_NONNULL_END
