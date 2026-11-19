# Third-party notices

SnapBeauty SDK and its models/resources are separately licensed. Check the provider terms and notices for the specific release before use or redistribution. The sample source and original artwork are covered by the repository license, except where otherwise noted.

## Locally supplied SDK

No beauty SDK binary, models or bundled SDK artwork are committed in this repository; SPM resolves the SDK separately.
The provider's applicable license and resource notices govern any locally supplied package and resulting application.

The sample's `ios/HostAssetsSource/makeup` artwork was independently authored from equations and pigment values. SDK layer filenames and UV coordinates are used only for interoperability. No reference artwork is an input. The sample artwork follows the repository license.

## iOS integrations

The iOS sample also uses the officially published iOS distributions: TXLiteAVSDK_TRTC 13.5.21355, AgoraRtcEngine_iOS/RtcBasic 4.6.4 with AgoraInfra_iOS 1.3.5, and ZegoExpressEngine/Video 3.25.0. Their applicable SDK/service terms remain separate from the sample Apache license. Podspec URLs, official binary URLs, versions and SHA-256 values are pinned in `ios/dependencies.lock.json`; binaries and their bundled notices are restored only into ignored local directories.

- Tencent RTC iOS API: https://trtc.io/document/50754
- Agora SDK license: https://github.com/AgoraIO/full-sdk/blob/master/LICENSE
- ZEGO legal portal: https://www.zego.im/policy

No vendor sample controller, branded icon or beauty artwork is copied into the iOS sample. The platform UI and frame adapters are authored in this repository. The original makeup artwork follows the repository license. The separately resolved SnapBeauty core, inference runtime, models and basic resources remain subject to their own applicable notices and redistribution conditions; their inclusion in a locally built app is not a grant of public redistribution rights.

XcodeGen 2.44.1 is an optional local project-generation tool (MIT, https://github.com/yonaskolb/XcodeGen); its binary is not committed. Apple platform frameworks are obtained through the user's Xcode installation. The iOS icon is rendered from this project's own geometric mark, using optional Pillow authoring tooling.

## 滤镜 LUT

`ios/HostAssetsSource/host-filters/luts/` 中的 10 张滤镜（`bright3`、`rose3`、`stylized11`、`mono1`、`warm1`、`warm2`、`fresh1`、`muted5`、`natural2`、`natural4`）不属于 SnapBeauty SDK，由本示例随 App 一起打包，在创建引擎后用 SDK 的 `registerFilter` 注册，之后和 SDK 内置滤镜一样用 `setFilter` 选择。

- 素材来源：RawTherapee Film Simulation Collection 2015-09-20（https://rawtherapee.com/shared/HaldCLUT.zip ），作者 **Pat David、Pavlov Dmitry、Michael Ezra**。
- 改动：重采样为 64³，用强度、提亮、冷暖、色调、饱和度、对比度六个全局参数调整，再三线性采样为 16³ 并量化为 RGB8（256×16）。
- 基于本示例发布 App 时，如保留这些滤镜，须一并保留上述署名与许可文件；不需要时删除该目录即可，其余功能不受影响。
