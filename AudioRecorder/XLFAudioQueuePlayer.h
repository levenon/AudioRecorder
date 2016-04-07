//
//  XLFAudioQueuePlayer
//  XLFAudioQueuePlayer
//
//  Created by molon on 5/12/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

/**
 *  使用audioqueque来实时播放，边播放边转码，可以设置自己的转码方式。从PCM数据转
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface XLFAudioQueuePlayer : NSObject

/**
 *  是否正在播放
 */
@property (atomic, assign, readonly) BOOL isPlaying;

- (void)appendAudioData:(NSData *)audioData;
- (void)stop;
- (void)start;

@end
