//
//  VideoRecordingViewController.m
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2024-06-06.
//  Copyright © 2024 Cascable AB.
//  For license information, see LICENSE.md.

#import "VideoRecordingViewController.h"
#import "Macros.h"

@interface VideoRecordingViewController ()
@property (nonatomic, readwrite) id <CBLCamera> camera;
@property (weak, nonatomic) IBOutlet UIImageView *liveViewImageView;
@property (weak, nonatomic) IBOutlet UILabel *recordingStateLabel;
@property (weak, nonatomic) IBOutlet UIButton *startStopRecordingButton;
@end

@implementation VideoRecordingViewController

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self addObserver:self forKeyPath:CBLKeyPath(self, camera.isRecordingVideo) options:0 context:nil];
        [self addObserver:self forKeyPath:CBLKeyPath(self, camera.currentVideoTimerValue) options:0 context:nil];
    }
    return self;
}

-(void)dealloc {
    // Turn off live view if it's running.
    if (self.camera.liveViewStreamActive) {
        [self.camera endLiveViewStream];
    }

    // Remove our observers.
    [self removeObserver:self forKeyPath:CBLKeyPath(self, camera.isRecordingVideo)];
    [self removeObserver:self forKeyPath:CBLKeyPath(self, camera.currentVideoTimerValue)];
}

-(void)viewDidLoad {
    [super viewDidLoad];
    self.recordingStateLabel.font = [UIFont monospacedDigitSystemFontOfSize:15.0 weight:UIFontWeightRegular];
}

#pragma mark - Live View

-(void)setupUIForCamera:(id <CBLCamera>)camera {

    self.camera = camera;

    CBLWeakify(self);
    CBLCameraLiveViewFrameDelivery delivery = ^(id<CBLCameraLiveViewFrame> frame, dispatch_block_t completionHandler) {
        CBLStrongify(self);

        // The live view image frame's image is always in the landscape orientation, even if the camera is rotated.
        // This is because focus areas etc. are always relative to the landscape orientation (i.e., when you rotate
        // the camera, the focus points rotate with it, so they're always relative to the landscape orientation).
        // If the camera supports live view orientation, the frame's orientation property may be something
        // other than CBLCameraLiveViewFrameOrientationLandscape, and you may choose to rotate your UI.
        self.liveViewImageView.image = frame.image;

        // We must call the completion handler once we're ready for more live view frames. Since we want a nice, smooth
        // image, we'll call the completion handler without delay.
        completionHandler();
    };

    [self.camera beginLiveViewStreamWithDelivery:delivery
                                   deliveryQueue:dispatch_get_main_queue()
                              terminationHandler:^(CBLCameraLiveViewTerminationReason reason, NSError * error) {
                                  if (error != nil) {
                                      NSLog(@"%@: Live view terminated with error: %@", THIS_FILE, error);
                                  } else {
                                      NSLog(@"%@: Terminated live view", THIS_FILE);
                                  }
                              }];
}

#pragma mark - Video Recording

-(IBAction)startOrStopVideoRecording:(id)sender {
    CBLErrorableOperationCallback responseHandler = ^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"%@: Video recording operation failed with error: %@", THIS_FILE, error.localizedDescription);
        }
    };

    if (!self.camera.isRecordingVideo) {
        // If you need fine-grained control when invoking focus, see the engageAutoFocus: et. al. methods.
        // IMPORTANT: The error parameter given in the callback only indicates whether the request was sent without error.
        [self.camera startVideoRecording:responseHandler];
    } else {
        [self.camera endVideoRecording:responseHandler];
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:CBLKeyPath(self, camera.isRecordingVideo)] ||
        [keyPath isEqualToString:CBLKeyPath(self, camera.currentVideoTimerValue)]) {
        [self updateVideoRecordingState];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

-(void)updateVideoRecordingState {

    if (!self.camera.isRecordingVideo) {
        [UIView performWithoutAnimation:^{
            self.recordingStateLabel.text = @"Not Recording";
            [self.startStopRecordingButton setTitle:@"Start Recording" forState:UIControlStateNormal];
            [self.startStopRecordingButton layoutIfNeeded];
        }];
    } else {
        [UIView performWithoutAnimation:^{
            [self.startStopRecordingButton setTitle:@"Stop Recording" forState:UIControlStateNormal];
            [self.startStopRecordingButton layoutIfNeeded];

            id <CBLVideoTimerValue> value = self.camera.currentVideoTimerValue;
            switch (value.type) {
                case CBLVideoTimerTypeNone:
                    self.recordingStateLabel.text = @"Recording";
                    break;
                case CBLVideoTimerTypeCountingDown:
                case CBLVideoTimerTypeCountingUp: {
                    NSInteger minutes = MAX(0, floor(value.value / 60.0));
                    NSInteger seconds = MAX(0, (NSInteger)floor(value.value) % 60);
                    self.recordingStateLabel.text = [NSString stringWithFormat:@"Recording: %ld:%02ld", minutes, seconds];
                    break;
                }
            }
        }];
    }
}

@end
