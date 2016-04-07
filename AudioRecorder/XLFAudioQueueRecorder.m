//
//  XLFAudioQueueRecorder
//  XLFAudioQueueRecorder
//
//  Created by molon on 5/12/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "XLFAudioQueueRecorder.h"
#import <AVFoundation/AVFoundation.h>


/**
 *  缓存区的个数，一般3个
 */
#define kNumberAudioQueueBuffers 3

/**
 *  采样率，要转码为amr的话必须为8000
 */
#define kDefaultSampleRate 8000

#define kDefaultInputBufferSize 7360


@interface XLFAudioQueueRecorder()
{
    //音频输入缓冲区
    AudioQueueBufferRef	_recordBuffers[kNumberAudioQueueBuffers];
}

@property (nonatomic, assign) BOOL isRecording;

@end

@implementation XLFAudioQueueRecorder

@synthesize recordQueue = _recordQueue;

- (id)init{
    
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)dealloc{
    
    if (self.isRecording){
        [self stop];
    }
    NSLog(@"XLFAudioQueueRecorder dealloc");
}

//录音回调
void GenericInputCallback (
                           void                                *inUserData,
                           AudioQueueRef                       inAQ,
                           AudioQueueBufferRef                 inBuffer,
                           const AudioTimeStamp                *inStartTime,
                           UInt32                              inNumberPackets,
                           const AudioStreamPacketDescription  *inPacketDescs
                           )
{
    NSLog(@"录音回调方法");
    
    XLFAudioQueueRecorder *recorder = (__bridge XLFAudioQueueRecorder*)inUserData;
    
    if (inNumberPackets > 0) {
        NSData *pcmData = [[NSData alloc] initWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
        
        if ([recorder delegate] && [[recorder delegate] respondsToSelector:@selector(audioQueueRecorder:didRecord:startTime:numPackets:packetDesc:)]) {
            [[recorder delegate] audioQueueRecorder:self didRecord:pcmData startTime:inStartTime numPackets:inNumberPackets packetDesc:inPacketDescs];
            NSLog(@"读取语音：%lu字节",(long)[pcmData length]);
        }
    }
    AudioQueueEnqueueBuffer (inAQ,inBuffer,0,NULL);
    
}

//初始化会话
- (void)initSession
{
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;         //可在后台播放声音
    AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
    
    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;  //设置成话筒模式
    AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                             sizeof (audioRouteOverride),
                             &audioRouteOverride);
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    //默认情况下扬声器播放
    BOOL ret = [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    if (!ret) {
        [self postAErrorWithErrorCode:XLFAudioQueueRecorderErrorCodeAboutSession andDescription:@"为AVAudioSession设置Category失败"];
        return;
    }
    ret = [audioSession setActive:YES error:nil];
    if (!ret){
        [self postAErrorWithErrorCode:XLFAudioQueueRecorderErrorCodeAboutSession andDescription:@"Active AVAudioSession失败"];
    }
}

#pragma mark - 私有方法
// 设置录音格式
- (void)setupAudioFormat:(UInt32)inFormatID SampleRate:(int)sampeleRate
{
    //重置下
    memset(&_recordFormat, 0, sizeof(_recordFormat));
    
    //设置采样率，这里先获取系统默认的测试下 //TODO:
    //采样率的意思是每秒需要采集的帧数
    _recordFormat.mSampleRate = sampeleRate;//[[AVAudioSession sharedInstance] sampleRate];
    
    //设置通道数,这里先使用系统的测试下 //TODO:
    _recordFormat.mChannelsPerFrame = 1;//(UInt32)[[AVAudioSession sharedInstance] inputNumberOfChannels];
    
    //设置format，怎么称呼不知道。
    _recordFormat.mFormatID = inFormatID;
    
    if (inFormatID == kAudioFormatLinearPCM){
        //这个屌属性不知道干啥的。，
        _recordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        //每个通道里，一帧采集的bit数目
        _recordFormat.mBitsPerChannel = 16;
        //结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte数目。
        //所以这里结果赋值给每帧需要采集的byte数目，然后这里的packet也等于一帧的数据。
        //至于为什么要这样。。。不知道。。。
        _recordFormat.mBytesPerPacket = _recordFormat.mBytesPerFrame = (_recordFormat.mBitsPerChannel / 8) * _recordFormat.mChannelsPerFrame;
        _recordFormat.mFramesPerPacket = 1;
    }
}

- (void)start{
    //设置录音的参数
    [self setupAudioFormat:kAudioFormatLinearPCM SampleRate:kDefaultSampleRate];
    
    _recordFormat.mSampleRate = kDefaultSampleRate;
    //创建一个录制音频队列
    AudioQueueNewInput (&(_recordFormat),GenericInputCallback,(__bridge void *)self,NULL,NULL,0,&_recordQueue);

    //设置话筒属性等
    [self initSession];
    
    NSError *error = nil;
    //设置audioSession格式 录音播放模式
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    
    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;  //设置成话筒模式
    AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                             sizeof (audioRouteOverride),
                             &audioRouteOverride);
    
    //创建录制音频队列缓冲区
    for (NSInteger i = 0; i < kNumberAudioQueueBuffers; i++) {
        AudioQueueAllocateBuffer (_recordQueue,kDefaultInputBufferSize,&_recordBuffers[i]);
        
        AudioQueueEnqueueBuffer (_recordQueue,(_recordBuffers[i]),0,NULL);
    }
    
    //开启录制队列
    AudioQueueStart(_recordQueue, NULL);
    
    self.isRecording = YES;
}

- (void)stop
{
    //    NSLog(@"stopRecording");
    if (self.isRecording) {
        self.isRecording = NO;
        
        //停止录音队列和移除缓冲区,以及关闭session，这里无需考虑成功与否
        AudioQueueStop(_recordQueue, true);
        AudioQueueDispose(_recordQueue, true);
        
        NSLog(@"录音结束");
        
        if(self.delegate&&[self.delegate respondsToSelector:@selector(didRecordStopped)]){
            [self.delegate didRecordStopped];
        }
        
        if (self.receiveStoppedBlock){
            self.receiveStoppedBlock();
        }
    }
}

- (void)postAErrorWithErrorCode:(XLFAudioQueueRecorderErrorCode)code andDescription:(NSString*)description
{
    //关闭可能还未关闭的东西,无需考虑结果
    self.isRecording = NO;
    
    AudioQueueStop(_recordQueue, true);
    AudioQueueDispose(_recordQueue, true);
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
    
    NSLog(@"录音发生错误");
    
    NSError *error = [NSError errorWithDomain:@"" code:code userInfo:@{NSLocalizedDescriptionKey:description}];
    
    if (self.delegate&&[self.delegate respondsToSelector:@selector(didRecordError:)]){
        [self.delegate didRecordError:error];
    }
    
    if( self.receiveErrorBlock){
        self.receiveErrorBlock(error);
    }
}

@end
