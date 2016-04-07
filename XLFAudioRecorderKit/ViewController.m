//
//  ViewController.m
//  XLFAudioQueueRecorderKit
//
//  Created by molon on 5/12/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "ViewController.h"
#import "XLFAudioQueueRecorder.h"
#import "XLFCafRecordWriter.h"
#import "XLFAmrRecordWriter.h"
#import "XLFMp3RecordWriter.h"
#import <AVFoundation/AVFoundation.h>
#import "XLFAudioMeterObserver.h"

@interface ViewController ()

@property (nonatomic, strong) XLFAudioQueueRecorder *recorder;

@property (nonatomic, strong) AVAudioPlayer *player;

@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@end

@implementation ViewController

- (void)dealloc
{
    //音谱检测关联着录音类，录音类要停止了。所以要设置其audioQueue为nil
    self.meterObserver.audioQueue = nil;
	[self.recorder stopRecording];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    XLFAudioQueueRecorder *recorder = [[XLFAudioQueueRecorder alloc]init];

    __weak __typeof(self)weakSelf = self;

    recorder.receiveStoppedBlock = ^{

        [weakSelf.recordButton setTitle:@"Record" forState:UIControlStateNormal];
        weakSelf.meterObserver.audioQueue = nil;
    };

    recorder.receiveErrorBlock = ^(NSError *error){

        [weakSelf.recordButton setTitle:@"Record" forState:UIControlStateNormal];
        weakSelf.meterObserver.audioQueue = nil;

        [[[UIAlertView alloc]initWithTitle:@"错误" message:error.userInfo[NSLocalizedDescriptionKey] delegate:nil cancelButtonTitle:nil otherButtonTitles:@"知道了", nil]show];
    };
    
    recorder.bufferDurationSeconds = 0.04;
    
    self.recorder = recorder;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)record:(id)sender {
    UIButton *recordButton = (UIButton*)sender;
    
    if (self.recorder.isRecording) {
        //取消录音
        [self.recorder stopRecording];
    }else{
        [recordButton setTitle:@"Stop" forState:UIControlStateNormal];
        //开始录音
        [self.recorder startRecording];
        self.meterObserver.audioQueue = self.recorder->_audioQueue;
    }
}

- (IBAction)play:(id)sender {
    self.player = [[AVAudioPlayer alloc]initWithContentsOfURL:[NSURL fileURLWithPath:self.filePath] error:nil];
    [self.player play];
    
}

@end
