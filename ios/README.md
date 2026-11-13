# iOS Samples

本目录为独立 iOS 示例工程。一个 Swift 应用提供相机美颜、腾讯云 TRTC、声网 Agora、即构 ZEGO 四个例子。

- Bundle ID：`ai.snapbeauty.samples`。
- iOS 15.0 起，真机 arm64；提供对应本地 SDK 构建后，也支持 Apple Silicon 模拟器。
- 界面、状态和相机使用 Swift / SwiftUI；Metal 与本地原生引擎边界使用 Objective-C++，RTC 接口适配使用 Objective-C。
- 本地预览自动开启，无需通话配置。只有主动填写配置并加入时才创建 RTC 引擎；麦克风默认关闭。

## 准备与构建

需要 macOS 和 Xcode。XcodeGen 2.44.1 仅在重新生成项目时需要。第三方 RTC 从官方发布源下载，版本、Podspec 和归档 SHA-256 固定在 `dependencies.lock.json`：

| 依赖 | iOS 版本 |
| --- | --- |
| 腾讯云 TXLiteAVSDK_TRTC | 13.5.21355 |
| AgoraRtcEngine_iOS / RtcBasic | 4.6.4 |
| AgoraInfra_iOS | 1.3.5 |
| ZegoExpressEngine / Video | 3.25.0 |

SnapBeauty 使用 Swift Package Manager 从 `https://github.com/YunJuChuang-Tech/snapbeauty-ios-sdk.git` 固定解析 `1.3.0`。项目依赖 `SnapBeautySDK` 产品，SDK 二进制、模型和平台 Metal 资源由 SPM 提供；示例自有妆容在运行时与 SDK 资源合并。

```sh
cd ios
python3 scripts/prepare.py
xcodebuild -project SnapBeautySamples.xcodeproj -scheme SnapBeautySamples \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/release CODE_SIGNING_ALLOWED=NO build
```

仅准备示例妆容和本地授权、不下载 RTC 时可使用 `python3 scripts/prepare.py --host-only`；仅准备 RTC 使用 `--rtc-only`。示例资源输出到 `.local/HostAssets/Assets`，SDK 本身由 Xcode 自动解析。项目文件已随仓库提供，XcodeGen 仅在重新生成项目时需要。

输出：`build/release/Build/Products/Release-iphoneos/SnapBeautySamples.app`。在 Xcode 选择自己的签名团队和对应 Bundle ID 的描述文件后即可安装；描述文件与签名资料不提交。

## 本地 SDK 授权

应用启动时调用 `SnapBeauty.initialize(license:)`。准备脚本默认使用仓库内 samples 的体验授权 `ios/SampleLicense/snapbeauty.license`。自行获取的授权可放在忽略的 `ios/.local/snapbeauty.license` 并重新运行准备脚本，该文件优先于默认授权。授权需与应用匹配；缺失或无效时返回原图并显示提示。示例桥接 UI 固定单人处理。

## 场景与效果

首页选择一个例子，进入后立即开启本地预览。相机权限首次按系统提示授权；加入房间时才填写 AppID、房间或频道、用户 ID / UID、UserSig / Token。Token 仅用于当前会话，不写入偏好设置、Bundle 状态、源码或诊断文案。需要麦克风时在加入前开启并授权。

交互按 Android 场景组织：相机、Agora、ZEGO 使用可收放面板，TRTC 使用“仅预览 / 加入房间 / 停止”、磨皮快捷条与“更多效果”。进入各例默认本地预览，效果状态按场景独立。通话页直接提供麦克风开关，默认关闭；房间表单记住各场景的 AppID、房间和用户，不保存 Token / UserSig。

共用面板包含 11 项美肤、25 项美型、15 套整妆、动态滤镜。四类选项均左右滑动，并分别记住选中参数；调整项显示描边，支持当前参数“恢复默认”和底部全部重置。默认dawn与 rose3 滤镜，浓度 40%；双向美型显示 −50…+50，0 为原始比例。支持按住对比、松开恢复、点击动画收放，以及从手柄或面板内容上下跟手拖动；横向选项和滑杆保留各自的手势。系统减少动态效果时关闭收放动画。面板覆盖在固定预览区域上，不通过拉伸相机画面实现收放。

妆容名称、SDK ID 和搭配滤镜由两端共用清单提供。选妆容自动带上滤镜，强度随妆容浓度变化；手动滤镜可独立覆盖，全部重置恢复dawn + rose3。

原始帧为 AVFoundation 输出的已旋正、未镜像 BGRA `CVPixelBuffer`。SnapBeauty 在串行处理边界内完成检测和 Metal 渲染，处理结果复制到拥有独立存储的 BGRA buffer。前置镜像只用于屏幕显示；显示以单一缩放因子中心裁切。由 Core Image 的 Metal 目的端处理显示坐标，不再额外翻转 Y；纹理读回行序与屏幕坐标不同，实际方向通过 MTKView / CAMetalLayer 屏幕截图独立校验，不改变交给 RTC 的图像。

| 场景 | 对外提交 |
| --- | --- |
| 相机 | 本地预览，不创建 RTC 会话 |
| TRTC | `enableCustomVideoCapture` + `sendCustomVideoData`，BGRA / PixelBuffer |
| Agora | 外部视频源 + `pushExternalVideoFrame`，`textureBuf` 为独立 PixelBuffer |
| ZEGO | 自定义 CVPixelBuffer 采集，只在 SDK 请求采集后提交 |

每例显示一个远端画面。退出回到本地预览；离开页面或切后台会停止采集并退出房间，回前台只恢复本地预览。旧帧、权限回调与会话回调带有代次检查，防止离开后或重新进入时影响新页面。

SDK 1.3.0 提供多脸、帧预算与重置接口；本轮示例保留单人处理方式。“人脸设置”显示当前示例范围；重置跟踪时重新创建引擎。返回纹理按实际 `pixelFormat` 转换为独立 BGRA buffer，兼容发布包可能返回的 RGBA。当前实现仍有 GPU 读回与 CPU 拷贝成本，长时功耗及真实网络推流尚未验证。

## 原创素材

准备脚本使用 `ios/HostAssetsSource/` 中的 53 份原创妆容文件，将其放入本地构建的 Assets。启动时验证全部 SHA-256。图标使用本项目的几何脸形、笑弧和光点；源为 `scripts/make_icon.py` 与 SwiftUI `SampleMark`，不使用第三方品牌图标。

正常构建无需重新绘制图标；可选运行 `python3 scripts/make_icon.py`（需要 Pillow）。资源哈希记录见 `HostAssetsSource/sample_makeup/manifest.json`。

## 验证

帧处理须串行调用。处理失败后显示实时原图，点击“重试美颜”重新创建引擎。SDK 处理错误与授权状态分别通过公开接口获取。

```sh
xcodebuild -project SnapBeautySamples.xcodeproj -scheme SnapBeautySamples \
  -destination 'platform=iOS Simulator,id=<your-simulator-uuid>' \
  -derivedDataPath build/simulator CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

测试包含配置校验、36 项参数索引、原生库加载、53 份资源完整性、真实 Metal 输出及输入/输出所有权、显示方向/镜像/等比裁切、四个场景入口及面板点击/手势、每类选择记忆/单项恢复/双向数值、房间非敏感配置保存。方向测试除纹理读回外，还在实际 MTKView / CAMetalLayer 屏幕截图上检查头部、下巴与左右镜像；合成图入口仅编入 Debug 模拟器版本。可选的人脸回归从测试 bundle 的 `Verification/portrait.jpg` 与 `regions.json` 读取本地素材：放在 `.local/Verification/` 后重新生成项目，未提供照片时明确跳过此项。测试照片和渲染输出不分发到 Release 应用。

独立仓库仍需在 Mac 上复验构建、测试和真机效果。官方接口依据：

- [TRTC Cloud iOS API](https://trtc.io/document/50754)
- [Agora iOS SDK API](https://api-ref.agora.io/en/video-sdk/ios/4.x/Classes/AgoraRtcEngineKit.html)
- [ZEGO iOS 自定义采集](https://www.zegocloud.com/docs/real-time-video-ios-oc/video/custom-video-capture)

各 SDK 的适用条款独立于示例，见 [第三方声明](../THIRD_PARTY_NOTICES.md)。
