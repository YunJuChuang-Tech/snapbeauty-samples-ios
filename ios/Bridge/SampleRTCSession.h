#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN
/// Vendor: 1 TRTC, 2 Agora, 3 ZEGO. Status: 0 idle, 1 joining, 2 joined.
@interface SampleRTCSession : NSObject
- (instancetype)initWithVendor:(NSInteger)vendor remoteView:(UIView *)remote status:(void (^)(NSString *, NSInteger))status;
- (BOOL)joinWithAppID:(NSString *)appID room:(NSString *)room user:(NSString *)user token:(NSString *)token microphone:(BOOL)microphone error:(NSError **)error
    NS_SWIFT_NAME(join(appID:room:user:token:microphone:));
- (void)sendPixelBuffer:(CVPixelBufferRef)buffer timestamp:(CMTime)timestamp NS_SWIFT_NAME(send(_:timestamp:));
- (void)stop;
- (BOOL)setMicrophoneEnabled:(BOOL)enabled error:(NSError **)error NS_SWIFT_NAME(setMicrophone(_:));
+ (NSDictionary<NSString *, NSString *> *)sdkVersions;
@end
NS_ASSUME_NONNULL_END
