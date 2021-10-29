//
//  RCRTCAudioReader.h
//  RCRTCAudioMix
//
//  Created by huan xu on 2021/10/28.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol  RCRTCAudioReaderDelegate<NSObject>

@optional
- (double)getCurrentTime;

- (void)onFinished;

@end


typedef NS_ENUM(NSUInteger, RCRTCAudioKTVMode) {
    RCRTCAudioKTVMode_Left,
    RCRTCAudioKTVMode_Right,
    RCRTCAudioKTVMode_Stereo,
    RCRTCAudioKTVMode_Balance,
};

@interface RCRTCAudioReader : NSObject

@property (nonatomic, assign) RCRTCAudioKTVMode ktvMode;

@property (nonatomic, readonly)AudioStreamBasicDescription audioFileFormat;

@property (nonatomic, weak) id<RCRTCAudioReaderDelegate> delegate;

- (instancetype)initWithPath:(NSString *)path outputFormat:(AudioStreamBasicDescription)format;

- (void)start;

- (double)getCurrentTime;

@end

NS_ASSUME_NONNULL_END
