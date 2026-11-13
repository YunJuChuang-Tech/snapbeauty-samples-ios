#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN
/// Serialized by the caller. Returned buffers are owned independently of SDK render targets.
@interface BeautyFrameProcessor : NSObject
+ (NSString *)sdkVersion;
+ (BOOL)licenseUsable;
@property(nonatomic, readonly) NSInteger faceCount;
@property(nonatomic, readonly) double costMilliseconds;
- (nullable instancetype)initWithAssets:(NSString *)assets shaders:(NSString *)shaders error:(NSError **)error;
- (nullable CVPixelBufferRef)process:(CVPixelBufferRef)input values:(NSArray<NSNumber *> *)values
    style:(nullable NSString *)style filter:(nullable NSString *)filter maxFaces:(NSInteger)maxFaces
    error:(NSError **)error CF_RETURNS_RETAINED;
- (void)resetTracking;
@end
NS_ASSUME_NONNULL_END
