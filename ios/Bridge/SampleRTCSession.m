#import "SampleRTCSession.h"
#import <TXLiteAVSDK_TRTC/TRTCCloud.h>
#import <AgoraRtcKit/AgoraRtcKit.h>
#import <ZegoExpressEngine/ZegoExpressEngine.h>

static BOOL ZegoDestroying = NO;

@interface SampleRTCSession () <TRTCCloudDelegate, AgoraRtcEngineDelegate, ZegoEventHandler, ZegoCustomVideoCaptureHandler>
@end

@implementation SampleRTCSession {
    NSInteger _vendor;
    UIView *_remote;
    void (^_status)(NSString *, NSInteger);
    TRTCCloud *_trtc;
    AgoraRtcEngineKit *_agora;
    ZegoExpressEngine *_zego;
    BOOL _active, _joined, _captureRequested, _microphone;
    NSUInteger _generation;
    NSString *_room, *_remoteUser, *_stream, *_remoteStream;
}
- (instancetype)initWithVendor:(NSInteger)vendor remoteView:(UIView *)remote status:(void (^)(NSString *, NSInteger))status {
    if ((self = [super init])) { _vendor = vendor; _remote = remote; _status = [status copy]; }
    return self;
}
+ (NSDictionary<NSString *,NSString *> *)sdkVersions {
    return @{ @"TRTC": [TRTCCloud getSDKVersion] ?: @"", @"Agora": [AgoraRtcEngineKit getSdkVersion] ?: @"", @"ZEGO": [ZegoExpressEngine getVersion] ?: @"" };
}
- (void)notify:(NSString *)message state:(NSInteger)state {
    void (^callback)(NSString *, NSInteger) = _status;
    NSUInteger generation = _generation;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        @synchronized (strongSelf) { if (generation != strongSelf->_generation) return; }
        callback(message, state);
    });
}
- (BOOL)joinWithAppID:(NSString *)appID room:(NSString *)room user:(NSString *)user token:(NSString *)token microphone:(BOOL)microphone error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"RTC lifecycle belongs to the UI thread");
    @synchronized (self) {
        if (_active) return NO;
        if (_vendor == 3) @synchronized (SampleRTCSession.class) {
            if (ZegoDestroying) {
                if (error) *error = [NSError errorWithDomain:@"ai.snapbeauty.samples.rtc" code:1 userInfo:@{NSLocalizedDescriptionKey: @"正在停止上一次会话，请稍后重试。"}];
                return NO;
            }
        }
        _active = YES; _joined = NO; _captureRequested = NO; _microphone = microphone; _room = room;
        NSUInteger generation = ++_generation;
        [self notify:@"正在加入…" state:1];
        if (_vendor == 1) {
            _trtc = [TRTCCloud sharedInstance]; [_trtc addDelegate:self];
            [_trtc enableCustomVideoCapture:TRTCVideoStreamTypeBig enable:YES];
            TRTCVideoEncParam *video = [TRTCVideoEncParam new];
            video.videoResolution = TRTCVideoResolution_640_480; video.resMode = TRTCVideoResolutionModePortrait;
            video.videoFps = 15; video.videoBitrate = 800; [_trtc setVideoEncoderParam:video];
            TRTCParams *params = [TRTCParams new]; params.sdkAppId = appID.intValue; params.roomId = room.intValue;
            params.userId = user; params.userSig = token; [_trtc enterRoom:params appScene:TRTCAppSceneVideoCall];
        } else if (_vendor == 2) {
            _agora = [AgoraRtcEngineKit sharedEngineWithAppId:appID delegate:self];
            [_agora setChannelProfile:AgoraChannelProfileCommunication];
            [_agora enableVideo]; [_agora enableLocalAudio:microphone];
            [_agora setExternalVideoSource:YES useTexture:YES sourceType:AgoraExternalVideoSourceTypeVideoFrame];
            AgoraRtcChannelMediaOptions *options = [AgoraRtcChannelMediaOptions new];
            options.publishCameraTrack = NO; options.publishCustomVideoTrack = YES; options.customVideoTrackId = 0;
            options.publishMicrophoneTrack = microphone; options.autoSubscribeAudio = YES; options.autoSubscribeVideo = YES;
            int result = [_agora joinChannelByToken:token channelId:room uid:user.integerValue mediaOptions:options joinSuccess:nil];
            if (result != 0) { [self fail:result]; return NO; }
        } else if (_vendor == 3) {
            ZegoEngineProfile *profile = [ZegoEngineProfile new]; profile.appID = (unsigned int)appID.longLongValue;
            profile.scenario = ZegoScenarioDefault;
            _zego = [ZegoExpressEngine createEngineWithProfile:profile eventHandler:self];
            [_zego enableAudioCaptureDevice:microphone]; [_zego muteMicrophone:!microphone];
            ZegoCustomVideoCaptureConfig *custom = [ZegoCustomVideoCaptureConfig new]; custom.bufferType = ZegoVideoBufferTypeCVPixelBuffer;
            [_zego enableCustomVideoCapture:YES config:custom]; [_zego setCustomVideoCaptureHandler:self];
            ZegoVideoConfig *video = [ZegoVideoConfig configWithPreset:ZegoVideoConfigPreset360P];
            video.captureResolution = CGSizeMake(480, 640); video.encodeResolution = CGSizeMake(480, 640); video.fps = 15;
            [_zego setVideoConfig:video];
            ZegoRoomConfig *config = [ZegoRoomConfig new]; config.token = token; config.isUserStatusNotify = YES;
            _stream = [NSString stringWithFormat:@"%@_%@", room, user];
            [_zego loginRoom:room user:[ZegoUser userWithUserID:user] config:config];
        } else { [self stop]; return NO; }
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) return;
            @synchronized (strongSelf) {
                if (strongSelf->_active && !strongSelf->_joined && generation == strongSelf->_generation) {
                    [strongSelf stop]; [strongSelf notify:@"加入超时，请检查网络和会话凭据。" state:0];
                }
            }
        });
        return YES;
    }
}
- (void)sendPixelBuffer:(CVPixelBufferRef)buffer timestamp:(CMTime)timestamp {
    @synchronized (self) {
        if (!_active || !_joined) return;
        if (_vendor == 1 && _trtc) {
            TRTCVideoFrame *frame = [TRTCVideoFrame new];
            frame.pixelFormat = TRTCVideoPixelFormat_32BGRA; frame.bufferType = TRTCVideoBufferType_PixelBuffer;
            frame.pixelBuffer = buffer; frame.width = (uint32_t)CVPixelBufferGetWidth(buffer); frame.height = (uint32_t)CVPixelBufferGetHeight(buffer);
            frame.rotation = TRTCVideoRotation_0; frame.timestamp = (uint64_t)(CMTimeGetSeconds(timestamp) * 1000);
            [_trtc sendCustomVideoData:TRTCVideoStreamTypeBig frame:frame];
        } else if (_vendor == 2 && _agora) {
            AgoraVideoFrame *frame = [AgoraVideoFrame new]; frame.format = 12; frame.textureBuf = buffer;
            frame.time = timestamp; frame.rotation = 0;
            if (![_agora pushExternalVideoFrame:frame videoTrackId:0]) [self notify:@"视频帧提交失败，请停止后重试。" state:2];
        } else if (_vendor == 3 && _zego && _captureRequested) {
            [_zego sendCustomVideoCapturePixelBuffer:buffer timestamp:timestamp];
        }
    }
}
- (BOOL)setMicrophoneEnabled:(BOOL)enabled error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"RTC lifecycle belongs to the UI thread");
    @synchronized (self) {
        if (!_active || !_joined) return YES;
        if (_agora) {
            AgoraRtcChannelMediaOptions *options = [AgoraRtcChannelMediaOptions new]; options.publishMicrophoneTrack = enabled;
            int result = [_agora enableLocalAudio:enabled];
            if (!result) result = [_agora updateChannelWithMediaOptions:options];
            if (result) {
                [_agora enableLocalAudio:_microphone];
                if (error) *error = [NSError errorWithDomain:@"ai.snapbeauty.samples.rtc" code:result userInfo:@{NSLocalizedDescriptionKey: @"麦克风切换失败，请稍后重试。"}];
                return NO;
            }
        }
        if (_trtc) { if (enabled) [_trtc startLocalAudio:TRTCAudioQualityDefault]; else [_trtc stopLocalAudio]; }
        if (_zego) { [_zego enableAudioCaptureDevice:enabled]; [_zego muteMicrophone:!enabled]; }
        _microphone = enabled; return YES;
    }
}
- (void)stop {
    NSAssert(NSThread.isMainThread, @"RTC lifecycle belongs to the UI thread");
    @synchronized (self) {
        _active = NO; _joined = NO; _captureRequested = NO; ++_generation;
        if (_trtc) {
            [_trtc removeDelegate:self]; [_trtc stopLocalAudio]; [_trtc stopAllRemoteView]; [_trtc exitRoom];
            [_trtc enableCustomVideoCapture:TRTCVideoStreamTypeBig enable:NO]; [TRTCCloud destroySharedInstance]; _trtc = nil;
        }
        if (_agora) {
            _agora.delegate = nil; [_agora enableLocalAudio:NO]; [_agora leaveChannel:nil]; [AgoraRtcEngineKit destroy]; _agora = nil;
        }
        if (_zego) {
            [_zego setCustomVideoCaptureHandler:nil]; [_zego enableAudioCaptureDevice:NO]; [_zego stopPublishingStream];
            if (_remoteStream) [_zego stopPlayingStream:_remoteStream]; [_zego logoutRoom];
            @synchronized (SampleRTCSession.class) { ZegoDestroying = YES; }
            [ZegoExpressEngine destroyEngine:^{ @synchronized (SampleRTCSession.class) { ZegoDestroying = NO; } }]; _zego = nil;
        }
        _room = nil; _stream = nil; _remoteStream = nil; _remoteUser = nil;
        dispatch_async(dispatch_get_main_queue(), ^{ for (UIView *view in self->_remote.subviews) [view removeFromSuperview]; });
    }
}
- (void)fail:(NSInteger)code {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_active) return;
        [strongSelf stop]; [strongSelf notify:[NSString stringWithFormat:@"连接错误（%ld），请检查配置后重试。", (long)code] state:0];
    });
}

// TRTC delegates are marshalled onto the main thread by the SDK.
- (void)onEnterRoom:(NSInteger)result {
    @synchronized (self) {
        if (!_active) return;
        if (result > 0) { _joined = YES; if (_microphone) [_trtc startLocalAudio:TRTCAudioQualityDefault]; [self notify:@"已加入房间，等待对方进入。" state:2]; }
        else [self fail:result];
    }
}
- (void)onError:(int)code extInfo:(NSString *)info { [self fail:code]; }
- (void)onUserVideoAvailable:(NSString *)userId available:(BOOL)available {
    if (!_active || !_joined) return;
    if (available && !_remoteUser) { _remoteUser = userId; [_trtc startRemoteView:userId streamType:TRTCVideoStreamTypeBig view:_remote]; }
    else if (!available && [_remoteUser isEqual:userId]) { [_trtc stopRemoteView:userId streamType:TRTCVideoStreamTypeBig]; _remoteUser = nil; }
}

// Agora creates no internal camera; all frames are upright, owned BGRA buffers.
- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinChannel:(NSString *)channel withUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    @synchronized (self) { if (!_active || engine != _agora) return; _joined = YES; }
    [self notify:@"已加入频道，等待对方进入。" state:2];
}
- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOccurError:(AgoraErrorCode)errorCode { [self fail:errorCode]; }
- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinedOfUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self->_active || self->_remoteUser) return;
        self->_remoteUser = [NSString stringWithFormat:@"%lu", (unsigned long)uid];
        AgoraRtcVideoCanvas *canvas = [AgoraRtcVideoCanvas new]; canvas.uid = uid; canvas.view = self->_remote; canvas.renderMode = AgoraVideoRenderModeHidden;
        [self->_agora setupRemoteVideo:canvas];
    });
}
- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOfflineOfUid:(NSUInteger)uid reason:(AgoraUserOfflineReason)reason {
    dispatch_async(dispatch_get_main_queue(), ^{ if (self->_remoteUser.integerValue == uid) { self->_remoteUser = nil; AgoraRtcVideoCanvas *canvas = [AgoraRtcVideoCanvas new]; canvas.uid = uid; [self->_agora setupRemoteVideo:canvas]; } });
}

// ZEGO only receives frames while its custom-capture request is active.
- (void)onStart:(ZegoPublishChannel)channel { @synchronized (self) { if (channel == ZegoPublishChannelMain) _captureRequested = YES; } }
- (void)onStop:(ZegoPublishChannel)channel { @synchronized (self) { if (channel == ZegoPublishChannelMain) _captureRequested = NO; } }
- (void)onRoomStateUpdate:(ZegoRoomState)state errorCode:(int)errorCode extendedData:(NSDictionary *)data roomID:(NSString *)roomID {
    @synchronized (self) {
        if (!_active || ![_room isEqual:roomID]) return;
        if (errorCode) { [self fail:errorCode]; return; }
        if (state == ZegoRoomStateConnected && !_joined) { _joined = YES; [_zego startPublishingStream:_stream]; [self notify:@"已加入房间，等待对方进入。" state:2]; }
    }
}
- (void)onPublisherStateUpdate:(ZegoPublisherState)state errorCode:(int)code extendedData:(NSDictionary *)data streamID:(NSString *)streamID { if (code) [self fail:code]; }
- (void)onRoomStreamUpdate:(ZegoUpdateType)type streamList:(NSArray<ZegoStream *> *)streams extendedData:(NSDictionary *)data roomID:(NSString *)roomID {
    if (!_active || !_joined) return;
    for (ZegoStream *stream in streams) {
        if ([stream.streamID isEqual:_stream]) continue;
        if (type == ZegoUpdateTypeAdd && !_remoteStream) {
            _remoteStream = stream.streamID; [_zego startPlayingStream:stream.streamID canvas:[ZegoCanvas canvasWithView:_remote]];
        } else if (type == ZegoUpdateTypeDelete && [stream.streamID isEqual:_remoteStream]) { [_zego stopPlayingStream:_remoteStream]; _remoteStream = nil; }
    }
}
@end
