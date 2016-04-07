//
//  XLFAudioMeterObserver.h
//  XLFAudioQueueRecorderKit
//
//  Created by molon on 5/13/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class XLFAudioMeterObserver;

typedef void (^XLFAudioMeterObserverActionBlock)(NSArray* levelMeterStates,XLFAudioMeterObserver *meterObserver);
typedef void (^XLFAudioMeterObserverErrorBlock)(NSError *error,XLFAudioMeterObserver *meterObserver);

/**
 *  错误标识
 */
typedef NS_OPTIONS(NSUInteger, XLFAudioMeterObserverErrorCode) {
    XLFAudioMeterObserverErrorCodeAboutQueue, //关于音频输入队列的错误
};



@interface LevelMeterState : NSObject

@property (nonatomic, assign) Float32 mAveragePower;

@end

@interface XLFAudioMeterObserver : NSObject

@property (nonatomic) AudioQueueRef audioQueue;

@property (nonatomic, copy) XLFAudioMeterObserverActionBlock actionBlock;

@property (nonatomic, copy) XLFAudioMeterObserverErrorBlock errorBlock;


@property (nonatomic, assign) NSTimeInterval refreshInterval; //刷新间隔,默认0.1

/**
 *  根据meterStates计算出音量，音量为 0-1
 *
 */
+ (Float32)volumeForLevelMeterStates:(NSArray*)levelMeterStates;

@end
