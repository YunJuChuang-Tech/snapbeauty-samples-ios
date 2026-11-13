# SnapBeauty iOS Samples

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS-blue.svg)](ios/README.md)

本仓库提供 SnapBeauty iOS SDK 接入示例，一个应用包含本地相机美颜，以及腾讯云 TRTC、声网 Agora 和即构 ZEGO 视频场景。

## 快速开始

需要 macOS、Xcode、iOS 15.0 或更新版本的设备，以及与应用绑定的有效 SDK 授权。SnapBeauty 通过 Swift Package Manager 固定版本 1.3.0；RTC 依赖由准备脚本从各厂商官方渠道获取并校验。

```sh
cd ios
python3 scripts/prepare.py
open SnapBeautySamples.xcodeproj
```

在 Xcode 配置自己的签名团队与 Bundle ID。仓库提供 samples 的 SDK 体验授权；如果使用自己的授权，将其存放在忽略的 `ios/.local/snapbeauty.license` 并重新运行准备脚本。授权须匹配应用，缺少或无效时显示原图。详细步骤和验证范围见 [iOS 工程说明](ios/README.md)。

## 目录

- `ios/`：Swift 应用、原生桥接、测试与准备脚本。
- `ios/HostAssetsSource/`：示例自有妆容资源。
- `ios/SampleLicense/`：samples 的 SDK 体验授权文件。
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)：第三方依赖及条款说明。


## 许可证

示例代码及自有素材采用 [Apache License 2.0](LICENSE)。SnapBeauty SDK 和第三方 RTC SDK 独立授权，须遵循各自的使用及分发条款。
