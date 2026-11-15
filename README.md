# 不用 Mac，把「效期扫码」装到 iPhone 上

两条路，都在这台 Windows 上能完成。**A 方案要 GitHub 账号，全程免费。**

---

## A 方案：GitHub 云端编译 + Sideloadly 签名（推荐，零成本）

原理：GitHub 免费提供 macOS 机器 → 自动编译出 IPA → 你在 Windows 上用 Sideloadly 用你的 Apple ID 签名装进手机。

### 第 1 步：把代码传到 GitHub（5 分钟，网页操作即可）

1. 打开 https://github.com 注册/登录
2. 右上角 **+ → New repository**
   - Repository name：`expiry-scan-ios`
   - 选 **Public**（公开仓库的 macOS 编译免费无限量）
   - 不要勾 Add README
3. 进入仓库 → **Add file → Upload files**
4. 把本文件夹里的 **`project.yml`、`Sources/`、`.github/`** 一起拖进去
   - 注意保持目录结构：`.github/workflows/build.yml` 必须在 `.github/workflows/` 下面
   - 网页上传时如果看不到 `.github` 文件夹，改用 GitHub Desktop 上传，或者在本机装 Git 后执行：
     ```
     git init
     git add .
     git commit -m "init"
     git branch -M main
     git remote add origin https://github.com/你的用户名/expiry-scan-ios.git
     git push -u origin main
     ```
5. 点 **Commit changes**

### 第 2 步：等云端编译（3~5 分钟）

1. 仓库顶部点 **Actions** 标签
2. 左边选 **build-ipa** → 右边 **Run workflow** → 绿色按钮
3. 等它跑完（绿勾）
4. 点进那次运行 → 页面底部 **Artifacts** → 下载 `ExpiryScan-unsigned-ipa`
5. 解压得到 **`ExpiryScan.ipa`**

### 第 3 步：在 Windows 上签名并装进 iPhone（10 分钟）

1. 装 **iTunes**（微软商店版即可，只为装 Apple 驱动）和 **Sideloadly**（https://sideloadly.io）
2. 数据线连上 iPhone，手机上点「信任此电脑」
3. 打开 Sideloadly：
   - **IPA** 处拖入 `ExpiryScan.ipa`
   - **Apple ID** 填你的 Apple ID
   - 点 **Start**，按提示输入密码和双重认证验证码
4. 装完后手机上：**设置 → 通用 → VPN与设备管理 → 开发者 App → 你的 Apple ID → 信任**
5. 回到桌面，点开「效期扫码」

### 第 4 步：7 天后怎么办

免费 Apple ID 的签名 **7 天过期**，App 会打不开（不是删掉，是启动失败）。
到期后重复「第 3 步」重新签一次即可，**数据通常保留**（同 bundle id 覆盖安装）。

想免去这个麻烦：买 $99/年 开发者账号（1 年），或用 AltStore / SideStore 在电脑上自动续签。

---

## B 方案：租一台云 Mac（¥10~30，省事）

1. 注册 MacinCloud / MacStadium，按小时计费（约 $1/小时）
2. 在云 Mac 上打开 Xcode → 把我给的 `Sources/` 直接拖进新建工程（见我另一份 README）
3. 用你的 Apple ID 签名，直接 Run 到手机（手机连不上云 Mac 时，可以先 Archive 导出 IPA，再用 Sideloadly 装）

适合只想点几下、不想碰 GitHub 的情况。

---

## 几个必须知道的点

| 事项 | 说明 |
|---|---|
| 我不会碰你的 Apple ID | 签名这一步必须你本人操作，我不会索取密码或验证码 |
| 建议用小号 | 用 Apple ID 在第三方工具登录有风险，建议专门注册一个 Apple ID 只用于签名 |
| 公开仓库 | 代码会公开可见。不想公开就建 Private 仓库，macOS 编译每月有 2000 分钟免费额度，够用几十次 |
| Bundle ID | `project.yml` 里是 `com.yourname.expiryscan`，随便改，只要和别人不重复 |
| 编译失败 | 把 Actions 里的红色日志发我，我改 `project.yml` 或源码 |

---

## 这个 App 的功能（和 Android 版对齐，除了闹钟）

- 扫标签二维码 → 自动解析品名 / 编号 / 到期时间
- **今日到期**（件数）、**次日到期**、**昨日到期** 三张明细卡
- 未来 7 天柱状图，今天那根是红的
- 同一效期重复扫 → 数量 ×N，全部记录里可以 +/− 调
- 从相册识别（Vision 框架，带 2×/3× 放大 + 四向旋转重试）
- 数据存本机，不联网

**本版不含任何提醒 / 通知 / 闹钟功能**，只做扫码、清单、统计、图表。
