//
//  XLFAudioQueuePlayer
//  XLFAudioQueuePlayer
//
//  Created by molon on 5/12/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "XLFAudioQueuePlayer.h"
#import <AVFoundation/AVFoundation.h>

/**
 *  缓存区的个数，一般3个
 */
#define kNumberAudioQueueBuffers 3

/**
 *  采样率，要转码为amr的话必须为8000
 */
#define kDefaultSampleRate 8000

#define kDefaultOutputBufferSize 7040

@interface XLFAudioQueuePlayer(){
    
    //音频输入数据format
    AudioStreamBasicDescription	_playFormat;
    //音频缓存
    AudioQueueBufferRef _playQueueBuffers[kNumberAudioQueueBuffers];
}

@property(nonatomic, strong) NSMutableArray* audioData;

// 音频播放队列
@property AudioQueueRef playQueue;

@property (atomic, assign) BOOL isPlaying;

@end

@implementation XLFAudioQueuePlayer

// 输出回调
void GenericOutputCallback (void                 *inUserData,
                            AudioQueueRef        inAQ,
                            AudioQueueBufferRef  inBuffer)
{
    NSLog(@"播放回调");
    XLFAudioQueuePlayer* player=(__bridge XLFAudioQueuePlayer*)inUserData;

    if([[player audioData] count] >0)
    {
        NSData *audioData = [[player audioData] firstObject];
        
        if (audioData) {
            if(audioData.length < 10000){
                memcpy(inBuffer->mAudioData, audioData.bytes, audioData.length);
                inBuffer->mAudioDataByteSize = (UInt32)audioData.length;
                inBuffer->mPacketDescriptionCount = 0;
            }
        }
        [[player audioData] removeObjectAtIndex:0];
    }
    else
    {
        makeSilent(inBuffer);
    }
    AudioQueueEnqueueBuffer([player playQueue],inBuffer,0,NULL);
}

- (instancetype)init{
    self = [super init];
    
    if (self) {
        
        [self setAudioData:[NSMutableArray array]];
    }
    return self;
}


- (void)dealloc{
    
    if (self.isPlaying){
        [self stop];
    }
    NSLog(@"XLFAudioQueueRecorder dealloc");
}

#pragma mark - 私有方法
// 设置录音格式
- (void)setupAudioFormat:(UInt32) inFormatID SampleRate:(int)sampeleRate
{
    //重置下
    memset(&_playFormat, 0, sizeof(_playFormat));
    
    //设置采样率，这里先获取系统默认的测试下 //TODO:
    //采样率的意思是每秒需要采集的帧数
    _playFormat.mSampleRate = sampeleRate;//[[AVAudioSession sharedInstance] sampleRate];
    
    //设置通道数,这里先使用系统的测试下 //TODO:
    _playFormat.mChannelsPerFrame = 1;//(UInt32)[[AVAudioSession sharedInstance] inputNumberOfChannels];
    
    //设置format，怎么称呼不知道。
    _playFormat.mFormatID = inFormatID;
    
    if (inFormatID == kAudioFormatLinearPCM){
        //这个屌属性不知道干啥的。，
        _playFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        //每个通道里，一帧采集的bit数目
        _playFormat.mBitsPerChannel = 16;
        //结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte数目。
        //所以这里结果赋值给每帧需要采集的byte数目，然后这里的packet也等于一帧的数据。
        //至于为什么要这样。。。不知道。。。
        _playFormat.mBytesPerPacket = _playFormat.mBytesPerFrame = (_playFormat.mBitsPerChannel / 8) * _playFormat.mChannelsPerFrame;
        _playFormat.mFramesPerPacket = 1;
    }
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
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
}

- (void)start{
   
    //设置录音的参数
    [self setupAudioFormat:kAudioFormatLinearPCM SampleRate:kDefaultSampleRate];
    
    _playFormat.mSampleRate = kDefaultSampleRate;
    //创建一个输出队列
    AudioQueueNewOutput(&_playFormat, GenericOutputCallback, (__bridge void *) self, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, 0,&_playQueue);
    //设置话筒属性等
    [self initSession];
    
    NSError *error = nil;
    //设置audioSession格式 录音播放模式
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    
    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;  //设置成话筒模式
    AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                             sizeof (audioRouteOverride),
                             &audioRouteOverride);
    
    //创建并分配缓冲区空间 4个缓冲区
    for (int i = 0; i<kNumberAudioQueueBuffers; ++i){
        
        AudioQueueAllocateBuffer(_playQueue, kDefaultOutputBufferSize, &_playQueueBuffers[i]);
    }
    for (int i=0; i < kNumberAudioQueueBuffers; ++i) {
        makeSilent(_playQueueBuffers[i]);  //改变数据
        // 给输出队列完成配置
        AudioQueueEnqueueBuffer(_playQueue,_playQueueBuffers[i],0,NULL);
    }
    
    Float32 gain = 1.0;                                       // 1
    // Optionally, allow user to override gain setting here 设置音量
    AudioQueueSetParameter (_playQueue,kAudioQueueParam_Volume,gain);
    
    //开启播放队列
    AudioQueueStart(_playQueue,NULL);
}

//把缓冲区置空
void makeSilent(AudioQueueBufferRef buffer){

    for (int i=0; i < buffer->mAudioDataBytesCapacity; i++) {
        buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
        UInt8 * samples = (UInt8 *) buffer->mAudioData;
        samples[i]=0;
    }
}

- (void)stop{
    
    if ([self isPlaying]) {
        
        [self setIsPlaying:NO];
        
        AudioQueueStop(_playQueue, true);
        AudioQueueDispose(_playQueue, YES);
    }
}

- (void)appendAudioData:(NSData *)audioData;{
    
    [[self audioData] addObject:audioData];
    
    NSLog(@"追加：%lu字节,当前：%lu",(long)[audioData length], (long)[[self audioData] count]);
}

@end
