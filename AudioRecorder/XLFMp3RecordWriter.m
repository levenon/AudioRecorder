//
//  XLFMp3RecordWriter.m
//  XLFAudioQueueRecorderKit
//
//  Created by molon on 5/13/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "XLFMp3RecordWriter.h"
#import "lame.h"

@interface XLFMp3RecordWriter()
{
    FILE *_file;
    lame_t _lame;
}

@property (nonatomic, assign) unsigned long recordedFileSize;
@property (nonatomic, assign) double recordedSecondCount;

@end

@implementation XLFMp3RecordWriter


- (BOOL)createFileWithRecorder:(XLFAudioQueueRecorder*)recoder;
{
    // mp3压缩参数
    _lame = lame_init();
	lame_set_num_channels(_lame, 1);
	lame_set_in_samplerate(_lame, 8000);
    lame_set_out_samplerate(_lame, 8000);
	lame_set_brate(_lame, 128);
	lame_set_mode(_lame, 1);
	lame_set_quality(_lame, 2);
	lame_init_params(_lame);
    
    //建立mp3文件
    _file = fopen((const char *)[self.filePath UTF8String], "wb+");
    if (_file==0) {
        NSLog(@"建立文件失败:%s",__FUNCTION__);
        return NO;
    }
    
    self.recordedFileSize = 0;
    self.recordedSecondCount = 0;
    
    NSLog(@"filePath:%@",self.filePath);
    
    return YES;
    
}

- (BOOL)writeIntoFileWithData:(NSData*)data
                 withRecorder:(XLFAudioQueueRecorder*)recoder
                         inAQ:(AudioQueueRef)inAQ
                  inStartTime:(const AudioTimeStamp *)inStartTime
                 inNumPackets:(UInt32)inNumPackets
                 inPacketDesc:(const AudioStreamPacketDescription*)inPacketDesc
{
    if (self.maxSecondCount>0){
        if (self.recordedSecondCount+recoder.bufferDurationSeconds>self.maxSecondCount){
            //            NSLog(@"录音超时");
            dispatch_async(dispatch_get_main_queue(), ^{
                [recoder stopRecording];
            });
            return YES;
        }
        self.recordedSecondCount += recoder.bufferDurationSeconds;
    }
    
    //编码
    short *recordingData = (short*)data.bytes;
    NSUInteger pcmLen = data.length;
    
    if (pcmLen<2){
        return YES;
    }
    
    NSUInteger nsamples = pcmLen / 2;
    
    unsigned char buffer[pcmLen];
    // mp3 encode
    int recvLen = lame_encode_buffer(_lame, recordingData, recordingData, (int)nsamples, buffer, (int)pcmLen);
    // add NSMutable
    if (recvLen>0) {
        if (self.maxFileSize>0){
            if(self.recordedFileSize+recvLen>self.maxFileSize){
                //                    NSLog(@"录音文件过大");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [recoder stopRecording];
                });
                return YES;//超过了最大文件大小就直接返回
            }
        }
        
        if(fwrite(buffer,1,recvLen,_file)==0){
            return NO;
        }
        self.recordedFileSize += recvLen;
    }
    
    return YES;
}

- (BOOL)completeWriteWithRecorder:(XLFAudioQueueRecorder*)recoder withIsError:(BOOL)isError
{
    //关闭就关闭吧。管他关闭成功与否
    if(_file){
        fclose(_file);
        _file = 0;
    }
    
    if(_lame){
        lame_close(_lame);
        _lame = 0;
    }
    
    return YES;
}

- (void)dealloc
{
	if(_file){
        fclose(_file);
        _file = 0;
    }
    
    if(_lame){
        lame_close(_lame);
        _lame = 0;
    }
}


@end
