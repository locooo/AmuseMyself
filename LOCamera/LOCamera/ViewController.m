//
//  ViewController.m
//  LOCamera
//
//  Created by locoo on 16/9/23.
//  Copyright © 2016年 locoo. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);
@interface ViewController ()
{
    AVCaptureSession *_aVCaptureSession;/**< 负责输入和输出设备之间的数据传递 */
    AVCaptureDeviceInput *_aVCaptureDeviceInput;/**< 负责从AVCaptureDevice获得输入数据 */
    AVCaptureStillImageOutput *_aVCaptureStillImageOutput;/**< 照片输出流 */
    AVCaptureVideoPreviewLayer *_aVCaptureVideoPreviewLayer;/**< 相机拍摄预览图层 */
    UIView *_aboveCaptureVideoPreviewLayerView;
    
    
    UIImageView *_focusCursor; /**< 聚焦光标 */
}

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
   
    [self setUPBack];
    [self addGenstureRecognizer];
    _focusCursor = [[UIImageView alloc]init];
    _focusCursor.backgroundColor = [UIColor redColor];
    _focusCursor.layer.backgroundColor = [UIColor yellowColor].CGColor;
    _focusCursor.frame = CGRectMake(0, 0, 20, 20);
    [_aVCaptureVideoPreviewLayer addSublayer:_focusCursor.layer];
   
    
}
-(void)setUPBack
{
    _aVCaptureSession = [[AVCaptureSession alloc]init];
    if ([_aVCaptureSession canSetSessionPreset:AVCaptureSessionPreset1280x720])
    {
        //设置分辨率
        _aVCaptureSession.sessionPreset=AVCaptureSessionPreset1280x720;
    }
    AVCaptureDevice *captureDevice=[self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];//取得后置摄像头
    if (!captureDevice) {
        NSLog(@"取得后置摄像头时出现问题.");
        return;
    }
    
    NSError *error=nil;
    //根据输入设备初始化设备输入对象，用于获得输入数据
    _aVCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    
    //初始化设备输出对象，用于获得输出数据
    _aVCaptureStillImageOutput=[[AVCaptureStillImageOutput alloc]init];
    NSDictionary *outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    [_aVCaptureStillImageOutput setOutputSettings:outputSettings];//输出设置
    
    //将设备输入添加到会话中
    if ([_aVCaptureSession canAddInput:_aVCaptureDeviceInput]) {
        [_aVCaptureSession addInput:_aVCaptureDeviceInput];
    }
    
    //将设备输出添加到会话中
    if ([_aVCaptureSession canAddOutput:_aVCaptureStillImageOutput]) {
        [_aVCaptureSession addOutput:_aVCaptureStillImageOutput];
    }
    
    
    //创建视频预览层，用于实时展示摄像头状态
    _aVCaptureVideoPreviewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:_aVCaptureSession];
    
    
    
    _aVCaptureVideoPreviewLayer.frame=CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height*0.5);
    _aVCaptureVideoPreviewLayer.masksToBounds = YES;
    _aVCaptureVideoPreviewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//填充模式
    //将视频预览层添加到界面中
    [self.view.layer addSublayer:_aVCaptureVideoPreviewLayer];
    
    //启动会话
    [_aVCaptureSession startRunning];


}
#pragma mark 切换前后摄像头
- (IBAction)toggleButtonClick:(UIButton *)sender {
    AVCaptureDevice *currentDevice=[_aVCaptureDeviceInput device];
    AVCaptureDevicePosition currentPosition=[currentDevice position];
    [self removeNotificationFromCaptureDevice:currentDevice];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition=AVCaptureDevicePositionFront;
    if (currentPosition==AVCaptureDevicePositionUnspecified||currentPosition==AVCaptureDevicePositionFront) {
        toChangePosition=AVCaptureDevicePositionBack;
    }
    toChangeDevice=[self getCameraDeviceWithPosition:toChangePosition];
    [self addNotificationToCaptureDevice:toChangeDevice];
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [_aVCaptureSession beginConfiguration];
    //移除原有输入对象
    [_aVCaptureSession removeInput:_aVCaptureDeviceInput];
    //添加新的输入对象
    if ([_aVCaptureSession canAddInput:toChangeDeviceInput]) {
        [_aVCaptureSession addInput:toChangeDeviceInput];
        _aVCaptureDeviceInput=toChangeDeviceInput;
    }
    //提交会话配置
    [_aVCaptureSession commitConfiguration];
    
    [self setFlashModeButtonStatus];
}
#pragma mark - 通知
/**
 *  给输入设备添加通知
 */
-(void)addNotificationToCaptureDevice:(AVCaptureDevice *)captureDevice
{
    //注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled=YES;
    }];
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //捕获区域发生改变
    [notificationCenter addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
-(void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)captureDevice{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
/**
 *  移除所有通知
 */
-(void)removeNotification{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self];
}

-(void)addNotificationToCaptureSession:(AVCaptureSession *)captureSession{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //会话出错
    [notificationCenter addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:captureSession];
}
/**
 *  设备连接成功
 *
 *  @param notification 通知对象
 */
-(void)deviceConnected:(NSNotification *)notification{
    NSLog(@"设备已连接...");
}
/**
 *  设备连接断开
 *
 *  @param notification 通知对象
 */
-(void)deviceDisconnected:(NSNotification *)notification{
    NSLog(@"设备已断开.");
}
/**
 *  捕获区域改变
 *
 *  @param notification 通知对象
 */
-(void)areaChange:(NSNotification *)notification{
    NSLog(@"捕获区域改变...");
}

/**
 *  会话出错
 *
 *  @param notification 通知对象
 */
-(void)sessionRuntimeError:(NSNotification *)notification{
    NSLog(@"会话发生错误.");
}
#pragma mark - 私有方法

/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [_aVCaptureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

/**
 *  设置闪光灯模式
 *
 *  @param flashMode 闪光灯模式
 */
-(void)setFlashMode:(AVCaptureFlashMode )flashMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice)
    {
        if ([captureDevice isFlashModeSupported:flashMode])
        {
            [captureDevice setFlashMode:flashMode];
        }
    }];
}
/**
 *  设置聚焦模式
 *
 *  @param focusMode 聚焦模式
 */
-(void)setFocusMode:(AVCaptureFocusMode )focusMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}
/**
 *  设置曝光模式
 *
 *  @param exposureMode 曝光模式
 */
-(void)setExposureMode:(AVCaptureExposureMode)exposureMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
}
/**
 *  设置聚焦点
 *
 *  @param point 聚焦点
 */
-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}

/**
 *  添加点按手势，点按时聚焦
 */
-(void)addGenstureRecognizer{
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.view addGestureRecognizer:tapGesture];
}
-(void)tapScreen:(UITapGestureRecognizer *)tapGesture{
    CGPoint point= [tapGesture locationInView:self.view];
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint= [_aVCaptureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
    NSLog(@"正在改变聚焦点");
}

/**
 *  设置闪光灯按钮状态
 */
-(void)setFlashModeButtonStatus{
    AVCaptureDevice *captureDevice=[_aVCaptureDeviceInput device];
    AVCaptureFlashMode flashMode=captureDevice.flashMode;
//    if([captureDevice isFlashAvailable]){
//        self.flashAutoButton.hidden=NO;
//        self.flashOnButton.hidden=NO;
//        self.flashOffButton.hidden=NO;
//        self.flashAutoButton.enabled=YES;
//        self.flashOnButton.enabled=YES;
//        self.flashOffButton.enabled=YES;
//        switch (flashMode) {
//            case AVCaptureFlashModeAuto:
//                self.flashAutoButton.enabled=NO;
//                break;
//            case AVCaptureFlashModeOn:
//                self.flashOnButton.enabled=NO;
//                break;
//            case AVCaptureFlashModeOff:
//                self.flashOffButton.enabled=NO;
//                break;
//            default:
//                break;
//        }
//    }else{
//        self.flashAutoButton.hidden=YES;
//        self.flashOnButton.hidden=YES;
//        self.flashOffButton.hidden=YES;
//    }
}
#pragma mark 自动闪光灯开启
- (IBAction)flashAutoClick:(id)sender {
    [self setFlashMode:AVCaptureFlashModeAuto];
    [self setFlashModeButtonStatus];
}
#pragma mark 打开闪光灯
- (IBAction)flashOnClick:(id)sender {
    [self setFlashMode:AVCaptureFlashModeOn];
    [self setFlashModeButtonStatus];
}
#pragma mark 关闭闪光灯
- (IBAction)flashOffClick:(id)sender {
    [self setFlashMode:AVCaptureFlashModeOff];
    [self setFlashModeButtonStatus];
}

#pragma mark 打开或关闭手电筒
-(void)openOrCloseTheFlashlight:(BOOL)openOrOff
{
     AVCaptureDevice *device=[_aVCaptureDeviceInput device];
    if (device.torchMode == AVCaptureTorchModeOff) {
        [device lockForConfiguration:nil];
        [device setTorchMode:AVCaptureTorchModeOn];
        [device unlockForConfiguration];
           }else{
        [device lockForConfiguration:nil];
        [device setTorchMode:AVCaptureTorchModeOff];
        [device unlockForConfiguration];
   
    }

}
/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
-(void)setFocusCursorWithPoint:(CGPoint)point{
    _focusCursor.center=point;
    _focusCursor.transform=CGAffineTransformMakeScale(1.5, 1.5);
    _focusCursor.alpha=1.0;
    [UIView animateWithDuration:1.0 animations:^{
        _focusCursor.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        _focusCursor.alpha=0;
        
    }];
}

- (IBAction)btnAction:(id)sender
{
    UIButton *btn = sender;
    if ([btn.currentTitle isEqualToString:@"切换镜头"])
    {
        [self toggleButtonClick:sender];
        
    }else if([btn.currentTitle isEqualToString:@"自动闪"])
    {
     
        [self flashAutoClick:sender];
    }else if([btn.currentTitle isEqualToString:@"闪光灯"])
    {
        
        [self flashOnClick:sender];
       
    }else if([btn.currentTitle isEqualToString:@"不闪"])
    {
        
         [self flashOffClick:sender];
    }else if([btn.currentTitle isEqualToString:@"打开或关闭手电筒"])
    {
        
        [self openOrCloseTheFlashlight:nil];
    }else if([btn.currentTitle isEqualToString:@"拍照"])
    {
        
        
        [self tackPhoto];
        [self toggleButtonClick:nil];
        [self tackPhoto];
        
        
        
        
        
        
        
    }
    
}
-(void)tackPhoto
{
    
    //根据设备输出获得连接
    AVCaptureConnection *captureConnection=[_aVCaptureStillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    [captureConnection setVideoScaleAndCropFactor:1.0 ];
    //根据连接取得设备输出的数据
    [_aVCaptureStillImageOutput captureStillImageAsynchronouslyFromConnection:captureConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer) {
            NSData *imageData=[AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image=[UIImage imageWithData:imageData];
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
            ALAssetsLibrary *assetsLibrary=[[ALAssetsLibrary alloc]init];
            [assetsLibrary writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
        }
        
    }];

    
}

- (IBAction)focalDistanceAction:(id)sender
{
    UISlider *slider= (UISlider*)sender;
    
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.25];
    [_aVCaptureVideoPreviewLayer setAffineTransform:CGAffineTransformMakeScale(slider.value, slider.value)];
    [CATransaction commit];
}





- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

}


@end
