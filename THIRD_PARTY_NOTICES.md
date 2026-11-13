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
