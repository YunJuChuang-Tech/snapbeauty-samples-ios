# SnapBeauty 宿主滤镜包（CC BY-SA 4.0）：来源、署名与改动

本目录的 10 张滤镜 LUT 不随 SDK 分发。需要这些滤镜的 App 自行打包本目录，并在运行时通过 SDK 的
`registerFilter` 接口注册，之后 `setFilter("<id>", 强度)` 的用法与内置滤镜相同。打包本目录的 App 是这些
LUT 的分发者，须遵守下文许可。不使用这些滤镜的 App 不需要附带本目录，也不需要下文署名。

## 原素材与署名

- 来源：RawTherapee Film Simulation Collection 2015-09-20，https://rawtherapee.com/shared/HaldCLUT.zip 。
- 署名：**Pat David、Pavlov Dmitry、Michael Ezra**。
- 许可：**CC BY-SA 4.0**，https://creativecommons.org/licenses/by-sa/4.0/ ，全文见 `LICENSE-CC-BY-SA-4.0.txt`。
- 原集合 README 按原字节保存在 `RawTherapee-README.txt`。

## 改动

SnapBeauty 项目对下表每个原始 Hald CLUT 做了以下改动：重采样为 64³，按六个全局参数（强度、提亮、冷暖、
色调、饱和度、对比度）调整，再三线性采样为 16³ 并量化为 RGB8，按 256×16 蓝切片横排存储。改编后的 LUT
继续按 **CC BY-SA 4.0** 提供，不加密、不限制提取，也不附加限制许可权利的条款。署名不表示原作者认可本项目
或使用本项目的 App。

## 逐项对应

| 文件 | 原始素材 | 许可 |
| --- | --- | --- |
| luts/bright3.png | HaldCLUT/Color/CreativePack-1/TealMagentaGold.png | CC-BY-SA-4.0 |
| luts/rose3.png | HaldCLUT/Color/Kodak/Kodak Kodachrome 200.png | CC-BY-SA-4.0 |
| luts/stylized11.png | HaldCLUT/Color/Polaroid/Polaroid 690 Cold 5 ++.png | CC-BY-SA-4.0 |
| luts/mono1.png | HaldCLUT/Black-and-White/Kodak/Kodak BW 400 CN.png | CC-BY-SA-4.0 |
| luts/warm1.png | HaldCLUT/Color/Kodak/Kodak Portra 400 1 -.png | CC-BY-SA-4.0 |
| luts/warm2.png | HaldCLUT/Color/Polaroid/Polaroid 669 4 +.png | CC-BY-SA-4.0 |
| luts/fresh1.png | HaldCLUT/Color/Fuji/Fuji Superia X-Tra 800.png | CC-BY-SA-4.0 |
| luts/muted5.png | HaldCLUT/Color/CreativePack-1/SoftWarming.png | CC-BY-SA-4.0 |
| luts/natural2.png | HaldCLUT/Color/Kodak/Kodak Portra 400 NC 1 -.png | CC-BY-SA-4.0 |
| luts/natural4.png | HaldCLUT/Color/Fuji/Fuji Superia 400 1 -.png | CC-BY-SA-4.0 |

逐项 SHA-256 见 `manifest.json`。
