#import "BeautyFrameProcessor.h"
#import "SnapBeauty.h"
#import <QuartzCore/QuartzCore.h>

// The app only maps its normalized controls and owns the returned video buffers.
// Tracking, models, resources and rendering belong to the released SDK.
@implementation BeautyFrameProcessor {
    SnapBeautyEngine *_engine;
    NSString *_assets;
    NSString *_shaders;
    double _cost;
    int64_t _timestamp;
}
+ (NSString *)sdkVersion { return [SnapBeautyEngine version]; }
+ (BOOL)licenseUsable { return [SnapBeauty licenseStatus].usable; }
- (instancetype)initWithAssets:(NSString *)assets shaders:(NSString *)shaders error:(NSError **)error {
    if ((self = [super init])) {
        _assets = [assets copy]; _shaders = [shaders copy];
        _engine = [[SnapBeautyEngine alloc] initWithAssetsPath:_assets shadersPath:_shaders error:error];
        if (!_engine) return nil;
    }
    return self;
}
- (NSInteger)faceCount { return _engine.faceCount; }
- (double)costMilliseconds { return _cost; }
- (CVPixelBufferRef)process:(CVPixelBufferRef)input values:(NSArray<NSNumber *> *)values style:(NSString *)style filter:(NSString *)filter maxFaces:(NSInteger)maxFaces error:(NSError **)error {
    if (values.count != 40 || maxFaces != 1) {
        if (error) *error = [NSError errorWithDomain:@"ai.snapbeauty.samples.processing" code:1
            userInfo:@{NSLocalizedDescriptionKey: @"当前版本仅支持单人处理，且需要完整的效果参数。"}];
        return nil;
    }
    if (!_engine) {
        _engine = [[SnapBeautyEngine alloc] initWithAssetsPath:_assets shadersPath:_shaders error:error];
        if (!_engine) return nil;
    }
    const double start = CACurrentMediaTime();
    SnapBeautySkinParams *skin = [SnapBeautySkinParams new];
    skin.smoothing = values[0].floatValue;
    skin.brightening = values[1].floatValue;
    skin.rosiness = values[2].floatValue;
    skin.sharpness = values[28].floatValue;
    skin.texture = values[29].floatValue;
    skin.blemishRemoval = values[30].floatValue;
    skin.eyeBrightening = values[31].floatValue;
    skin.teethWhitening = values[32].floatValue;
    skin.undereyeBags = values[33].floatValue;
    skin.smileLines = values[34].floatValue;
    skin.faceContour = values[35].floatValue;
    SnapBeautyFaceParams *face = [SnapBeautyFaceParams new];
    face.faceSlimming = values[3].floatValue;
    face.faceVTaper = values[4].floatValue;
    face.faceNarrowing = values[5].floatValue;
    face.faceShortening = values[6].floatValue;
    face.faceShrinking = values[7].floatValue;
    face.cheekboneWidth = values[8].floatValue;
    face.jawWidth = values[9].floatValue;
    face.eyeScale = values[10].floatValue;
    face.eyeRoundness = values[11].floatValue;
    face.chinLength = values[12].floatValue;
    face.foreheadHeight = values[13].floatValue;
    face.noseWidth = values[14].floatValue;
    face.mouthSize = values[15].floatValue;
    face.lipFullness = values[16].floatValue;
    face.eyePosition = values[17].floatValue;
    face.eyeCornerOpening = values[18].floatValue;
    face.eyelidFold = values[19].floatValue;
    face.eyeDistance = values[20].floatValue;
    face.eyeTilt = values[21].floatValue;
    face.noseLength = values[22].floatValue;
    face.philtrumLength = values[23].floatValue;
    face.mouthCorners = values[24].floatValue;
    face.browPosition = values[25].floatValue;
    face.browDistance = values[26].floatValue;
    face.browThickness = values[27].floatValue;
    _engine.skin = skin; _engine.face = face;
    [_engine setMakeup:style strength:values[36].floatValue];
    [_engine setFilter:filter strength:values[37].floatValue];
    _timestamp = MAX(_timestamp + 1, (int64_t)(CACurrentMediaTime() * 1e9));
    id<MTLTexture> texture = [_engine processPixelBuffer:input frontCamera:NO timestamp:_timestamp showOriginal:NO error:error];
    if (!texture) return nil;
    CVPixelBufferRef output = nil;
    NSDictionary *attributes = @{(id)kCVPixelBufferIOSurfacePropertiesKey: @{}, (id)kCVPixelBufferMetalCompatibilityKey: @YES};
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault, texture.width, texture.height,
        kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)attributes, &output);
    if (result != kCVReturnSuccess) {
        if (error) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result userInfo:nil];
        return nil;
    }
    result = CVPixelBufferLockBaseAddress(output, 0);
    if (result != kCVReturnSuccess) {
        CFRelease(output);
        if (error) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result userInfo:nil];
        return nil;
    }
    [texture getBytes:CVPixelBufferGetBaseAddress(output) bytesPerRow:CVPixelBufferGetBytesPerRow(output)
        fromRegion:MTLRegionMake2D(0, 0, texture.width, texture.height) mipmapLevel:0];
    // The release can return RGBA render targets despite documenting BGRA output.
    // Convert according to the actual Metal format before handing frames to RTC.
    if (texture.pixelFormat == MTLPixelFormatRGBA8Unorm) {
        uint8_t *bytes = (uint8_t *)CVPixelBufferGetBaseAddress(output);
        size_t stride = CVPixelBufferGetBytesPerRow(output);
        for (NSUInteger y = 0; y < texture.height; ++y) for (NSUInteger x = 0; x < texture.width; ++x) {
            uint8_t *pixel = bytes + y * stride + x * 4;
            uint8_t red = pixel[0]; pixel[0] = pixel[2]; pixel[2] = red;
        }
    }
    CVPixelBufferUnlockBaseAddress(output, 0);
    _cost = (CACurrentMediaTime() - start) * 1000;
    return output;
}
- (void)resetTracking { _engine = nil; }
@end
