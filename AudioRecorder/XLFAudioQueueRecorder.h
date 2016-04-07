//
//  XLFAudioQueueRecorder.h
//  XLFAudioQueueRecorder
//
//  Created by molon on 5/12/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

/**
 *  使用audioqueque来实时录音，边录音边转码，可以设置自己的转码方式。从PCM数据转
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

//录音停止事件的block回调，作用参考XLFAudioQueueRecorderDelegate的recordStopped和recordError:
typedef void (^XLFAudioQueueRecorderReceiveStoppedBlock)();
typedef void (^XLFAudioQueueRecorderReceiveErrorBlock)(NSError *error);

/**
 *  错误标识
 */
typedef NS_OPTIONS(NSUInteger, XLFAudioQueueRecorderErrorCode) {
    XLFAudioQueueRecorderErrorCodeAboutFile = 0, //关于文件操作的错误
    XLFAudioQueueRecorderErrorCodeAboutQueue, //关于音频输入队列的错误
    XLFAudioQueueRecorderErrorCodeAboutSession, //关于audio session的错误
    XLFAudioQueueRecorderErrorCodeAboutOther, //关于其他的错误
};

@class XLFAudioQueueRecorder;

@protocol XLFAudioQueueRecorderDelegate <NSObject>

@optional
/**
 *  录音遇到了错误，例如创建文件失败啊。写入失败啊。关闭文件失败啊，等等。
 */
- (void)didRecordError:(NSError *)error;

/**
 *  录音被停止
 *  一般是在writer delegate中因为一些状况意外停止录音获得此事件时候使用，参考XLFAmrRecordWriter里实现。
 */
- (void)didRecordStopped;

- (void)audioQueueRecorder:(XLFAudioQueueRecorder *)audioQueueRecorder didRecord:(NSData*)data startTime:(const AudioTimeStamp *)startTime numPackets:(UInt32)numPackets packetDesc:(const AudioStreamPacketDescription *)packetDesc;

@end

@interface XLFAudioQueueRecorder : NSObject
{
    @public
    //音频输入队列
    AudioQueueRef				_recordQueue;
    //音频输入数据format
    AudioStreamBasicDescription	_recordFormat;
}


@property AudioQueueRef	recordQueue;

/**
 *  是否正在录音
 */
@property (atomic, assign,readonly) BOOL isRecording;

/**
 *  参考XLFAudioQueueRecorderReceiveStoppedBlock和XLFAudioQueueRecorderReceiveErrorBlock
 */
@property (nonatomic, copy) XLFAudioQueueRecorderReceiveStoppedBlock receiveStoppedBlock;
@property (nonatomic, copy) XLFAudioQueueRecorderReceiveErrorBlock receiveErrorBlock;

/**
 *  参考XLFAudioQueueRecorderDelegate
 */
@property (nonatomic, assign) id<XLFAudioQueueRecorderDelegate> delegate;

- (void)start;
- (void)stop;


@end
