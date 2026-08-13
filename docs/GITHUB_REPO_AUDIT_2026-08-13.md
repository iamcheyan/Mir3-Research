# GitHub iamcheyan 仓库审计报告 (2026-08-13)

> 生成时间：2026-08-14 · 数据源：GitHub REST API (`gh repo list --limit 500`) · 全量 177 仓库

> 说明：本报告只给建议，未执行任何 delete/archive/visibility 变更。唯一已执行的写操作是对缺 description 仓库补英文描述（§5）。
> 私有仓库的具体内容已脱敏（描述显示 `(private — hidden)`）。🔒 = 私有，🍴 = fork。

## 0. 总览

| 指标 | 数值 |
|---|---|
| 总数 | 177 |
| 公开 / 私有 | 146 / 31 |
| fork / 自有 | 53 / 124 |
| 已归档 | 0 |
| 空仓库 | 4 |
| 缺 description（补前 / 补后） | 97 / 0 |

- **keep**: 41
- **unfork-keep**: 12
- **describe-only**: 25
- **archive**: 60
- **delete-candidate**: 39

## 1. 建议删除 (delete-candidate)

以下为建议（未执行）。纯镜像 fork 删除后可随时重新 fork；空仓库无内容。**删除前请自行确认。**

| 仓库 | 类型 | 上游 | 距上次push(天) | stars | 理由 |
|---|---|---|---|---|---|
| [Alice](https://github.com/iamcheyan/Alice) | fork | sofish/Alice | 5333 | 1 | pure mirror of sofish/Alice (no own commits, behind) |
| [Android16-Origin-Debian12-GUI](https://github.com/iamcheyan/Android16-Origin-Debian12-GUI) | fork | xlzhen-940218/Android16-Origin-Debian12-GUI | 227 | 0 | pure mirror of xlzhen-940218/Android16-Origin-Debian12-GUI (no own commits, behind) |
| [Humanizer-zh](https://github.com/iamcheyan/Humanizer-zh) | fork | op7418/Humanizer-zh | 207 | 0 | pure mirror of op7418/Humanizer-zh (no own commits, identical) |
| [MirForGodot](https://github.com/iamcheyan/MirForGodot) | fork | makeryangcom/MirForGodot | 724 | 0 | pure mirror of makeryangcom/MirForGodot (no own commits, identical) |
| [Simplified-AZIK](https://github.com/iamcheyan/Simplified-AZIK) | fork | yuru7/Simplified-AZIK | 1487 | 0 | pure mirror of yuru7/Simplified-AZIK (no own commits, identical) |
| [Waybar](https://github.com/iamcheyan/Waybar) | fork | Alexays/Waybar | 42 | 0 | pure mirror of Alexays/Waybar (no own commits, behind) |
| [agent](https://github.com/iamcheyan/agent) 🔒 | own | - | 99 | 0 | empty repository |
| [azik-roman-table](https://github.com/iamcheyan/azik-roman-table) | fork | toriwasa/azik-roman-table | 579 | 1 | pure mirror of toriwasa/azik-roman-table (no own commits, identical) |
| [cc-switch-cli](https://github.com/iamcheyan/cc-switch-cli) | fork | SaladDay/cc-switch-cli | 96 | 0 | pure mirror of SaladDay/cc-switch-cli (no own commits, behind) |
| [con-terminal](https://github.com/iamcheyan/con-terminal) | fork | nowledge-co/con-terminal | 103 | 0 | pure mirror of nowledge-co/con-terminal (no own commits, behind) |
| [css-auto-reload](https://github.com/iamcheyan/css-auto-reload) | fork | allenm/css-auto-reload | 5181 | 1 | pure mirror of allenm/css-auto-reload (no own commits, behind) |
| [distro-grub-themes](https://github.com/iamcheyan/distro-grub-themes) | fork | AdisonCavani/distro-grub-themes | 712 | 0 | pure mirror of AdisonCavani/distro-grub-themes (no own commits, behind) |
| [down2nas](https://github.com/iamcheyan/down2nas) | own | - | 70 | 0 | empty repository, never initialized |
| [fcitx5-vinput](https://github.com/iamcheyan/fcitx5-vinput) | fork | xifan2333/fcitx5-vinput | 110 | 0 | pure mirror of xifan2333/fcitx5-vinput (no own commits, behind) |
| [folderify](https://github.com/iamcheyan/folderify) | fork | lgarron/folderify | 686 | 0 | pure mirror of lgarron/folderify (no own commits, behind) |
| [fontconfig-zh-cn](https://github.com/iamcheyan/fontconfig-zh-cn) | fork | ohmyarch/fontconfig-zh-cn | 3412 | 0 | pure mirror of ohmyarch/fontconfig-zh-cn (no own commits, identical) |
| [fonts](https://github.com/iamcheyan/fonts) | fork | owent-utils/font | 3403 | 0 | pure mirror of owent-utils/font (no own commits, identical) |
| [fudu](https://github.com/iamcheyan/fudu) | own | - | 75 | 0 | empty repository, never initialized |
| [gentle-ai](https://github.com/iamcheyan/gentle-ai) | fork | Gentleman-Programming/gentle-ai | 48 | 0 | pure mirror of Gentleman-Programming/gentle-ai (no own commits, behind) |
| [hunk](https://github.com/iamcheyan/hunk) | fork | modem-dev/hunk | 95 | 0 | pure mirror of modem-dev/hunk (no own commits, behind) |
| [hyprquickframe](https://github.com/iamcheyan/hyprquickframe) | fork | Ronin-CK/HyprQuickFrame | 74 | 0 | pure mirror of Ronin-CK/HyprQuickFrame (no own commits, identical) |
| [jQuery-menu-aim](https://github.com/iamcheyan/jQuery-menu-aim) | fork | kamens/jQuery-menu-aim | 4909 | 0 | pure mirror of kamens/jQuery-menu-aim (no own commits, behind) |
| [jquery-color](https://github.com/iamcheyan/jquery-color) | fork | jquery/jquery-color | 4699 | 0 | pure mirror of jquery/jquery-color (no own commits, behind) |
| [just-talk](https://github.com/iamcheyan/just-talk) | fork | whoamihappyhacking/just-talk | 161 | 0 | pure mirror of whoamihappyhacking/just-talk (no own commits, behind) |
| [kissy](https://github.com/iamcheyan/kissy) | fork | kissyteam/kissy | 5244 | 1 | pure mirror of kissyteam/kissy (no own commits, behind) |
| [mistermorph](https://github.com/iamcheyan/mistermorph) | fork | quailyquaily/mistermorph | 103 | 0 | pure mirror of quailyquaily/mistermorph (no own commits, behind) |
| [noctalia](https://github.com/iamcheyan/noctalia) | fork | noctalia-dev/noctalia | 33 | 0 | pure mirror of noctalia-dev/noctalia (no own commits, behind) |
| [omarchy](https://github.com/iamcheyan/omarchy) | fork | basecamp/omarchy | 53 | 0 | pure mirror of basecamp/omarchy (no own commits, behind) |
| [openWarp](https://github.com/iamcheyan/openWarp) | fork | zerx-lab/zap | 104 | 0 | pure mirror of zerx-lab/zap (no own commits, behind) |
| [opencode-studio](https://github.com/iamcheyan/opencode-studio) | fork | Microck/opencode-studio | 96 | 0 | pure mirror of Microck/opencode-studio (no own commits, behind) |
| [opencode2api](https://github.com/iamcheyan/opencode2api) | fork | TiaraBasori/OpenCode2API | 118 | 0 | pure mirror of TiaraBasori/OpenCode2API (no own commits, behind) |
| [paopao-ce](https://github.com/iamcheyan/paopao-ce) | fork | rocboss/paopao-ce | 326 | 0 | pure mirror of rocboss/paopao-ce (no own commits, behind) |
| [pi4aws](https://github.com/iamcheyan/pi4aws) 🔒 | own | - | 58 | 0 | empty repository |
| [rime-double-pinyin](https://github.com/iamcheyan/rime-double-pinyin) | fork | rime/rime-double-pinyin | 2454 | 0 | pure mirror of rime/rime-double-pinyin (no own commits, behind) |
| [tidy-sddm](https://github.com/iamcheyan/tidy-sddm) | fork | loadfred/tidy-sddm | 638 | 0 | pure mirror of loadfred/tidy-sddm (no own commits, identical) |
| [tolaria](https://github.com/iamcheyan/tolaria) | fork | refactoringhq/tolaria | 108 | 0 | pure mirror of refactoringhq/tolaria (no own commits, behind) |
| [vim-private](https://github.com/iamcheyan/vim-private) | fork | e7h4n/vim-private | 5160 | 1 | pure mirror of e7h4n/vim-private (no own commits, behind) |
| [wechat-selkies](https://github.com/iamcheyan/wechat-selkies) | fork | nickrunning/wechat-selkies | 129 | 0 | pure mirror of nickrunning/wechat-selkies (no own commits, behind) |
| [zircon-legend-laucher](https://github.com/iamcheyan/zircon-legend-laucher) | fork | raphaelcheung/zircon-legend-laucher | 478 | 0 | pure mirror of raphaelcheung/zircon-legend-laucher (no own commits, identical) |

## 2. 建议归档 (archive)

| 仓库 | 语言 | stars | 距上次push(天) | README | 理由 |
|---|---|---|---|---|---|
| [sublime-gbk](https://github.com/iamcheyan/sublime-gbk) | Python | 1 | 5267 | ✓ | long dormant (5267d) but has content |
| [Markdown-Syntax-CN](https://github.com/iamcheyan/Markdown-Syntax-CN) | Perl | 1 | 5246 | ✓ | long dormant (5246d) but has content |
| [leng](https://github.com/iamcheyan/leng) | JavaScript | 1 | 5162 | ✗ | long dormant (5162d) but has content |
| [iamcheyan.com-for-wordpress](https://github.com/iamcheyan/iamcheyan.com-for-wordpress) | PHP | 2 | 5159 | ✓ | long dormant (5159d) but has content |
| [pentadactylrc](https://github.com/iamcheyan/pentadactylrc) | JavaScript | 3 | 5159 | ✓ | long dormant (5159d) but has content |
| [MacVim](https://github.com/iamcheyan/MacVim) | Vim Script | 6 | 5153 | ✓ | long dormant (5153d) but has content |
| [panel_for_zhihu](https://github.com/iamcheyan/panel_for_zhihu) | JavaScript | 2 | 3514 | ✓ | long dormant (3514d) but has content |
| [Sanhua-cat-Makedown2Html](https://github.com/iamcheyan/Sanhua-cat-Makedown2Html) | - | 0 | 1045 | ✓ | long dormant (1045d) but has content |
| [simple_translation](https://github.com/iamcheyan/simple_translation) | Python | 0 | 997 | ✓ | long dormant (997d) but has content |
| [Pelican-Random-Article-Loader-Plugin](https://github.com/iamcheyan/Pelican-Random-Article-Loader-Plugin) | JavaScript | 0 | 993 | ✓ | long dormant (993d) but has content |
| [OrchideaDock](https://github.com/iamcheyan/OrchideaDock) | CSS | 6 | 674 | ✓ | inactive 674d, has content worth keeping |
| [AcrobatProDC_Linux_AppImage](https://github.com/iamcheyan/AcrobatProDC_Linux_AppImage) | - | 0 | 636 | ✓ | notes-only repo (README stub, 0 KB content), inactive 637d |
| [7z-for-Linux](https://github.com/iamcheyan/7z-for-Linux) | Shell | 2 | 635 | ✓ | inactive 635d, has content worth keeping |
| [cursor](https://github.com/iamcheyan/cursor) | Shell | 4 | 399 | ✓ | inactive 399d, has content worth keeping |
| [xiaoshuo](https://github.com/iamcheyan/xiaoshuo) 🔒 | Python | 0 | 355 | ✓ | private repo — inactive 355d |
| [MobileTransfer](https://github.com/iamcheyan/MobileTransfer) | Swift | 1 | 343 | ✓ | inactive 343d, has content worth keeping |
| [KamiNeko](https://github.com/iamcheyan/KamiNeko) | Swift | 0 | 341 | ✓ | inactive 341d, has content worth keeping |
| [MeloTTSBOOK](https://github.com/iamcheyan/MeloTTSBOOK) 🔒 | Python | 0 | 340 | ✓ | private repo — inactive 340d |
| [Maibook](https://github.com/iamcheyan/Maibook) 🔒 | HTML | 0 | 323 | ✓ | private repo — inactive 323d |
| [Tools](https://github.com/iamcheyan/Tools) 🔒 | Python | 0 | 323 | ✗ | private repo — inactive 323d |
| [GuestHouse](https://github.com/iamcheyan/GuestHouse) 🔒 | HTML | 0 | 321 | ✓ | private repo — inactive 321d |
| [MINIQuaily](https://github.com/iamcheyan/MINIQuaily) | JavaScript | 0 | 319 | ✗ | inactive 319d, has content worth keeping |
| [KamiNeko-web](https://github.com/iamcheyan/KamiNeko-web) | JavaScript | 0 | 319 | ✓ | inactive 319d, has content worth keeping |
| [KKAB-github](https://github.com/iamcheyan/KKAB-github) | HTML | 0 | 318 | ✓ | inactive 318d, has content worth keeping |
| [Nano](https://github.com/iamcheyan/Nano) 🔒 | HTML | 0 | 308 | ✓ | private repo — inactive 308d |
| [Yomimo](https://github.com/iamcheyan/Yomimo) | HTML | 0 | 304 | ✓ | inactive 304d, has content worth keeping |
| [veikin.com](https://github.com/iamcheyan/veikin.com) | CSS | 0 | 300 | ✗ | inactive 300d, has content worth keeping |
| [WOODS40](https://github.com/iamcheyan/WOODS40) | HTML | 2 | 293 | ✓ | inactive 293d, has content worth keeping |
| [zmk-config](https://github.com/iamcheyan/zmk-config) | C | 0 | 290 | ✓ | inactive 290d, has content worth keeping |
| [Kotoba-WXSS](https://github.com/iamcheyan/Kotoba-WXSS) | JavaScript | 0 | 287 | ✓ | inactive 287d, has content worth keeping |
| [go_beautifulllife](https://github.com/iamcheyan/go_beautifulllife) | HTML | 0 | 284 | ✗ | inactive 284d, has content worth keeping |
| [sbzr-chrome](https://github.com/iamcheyan/sbzr-chrome) | JavaScript | 0 | 281 | ✗ | inactive 281d, has content worth keeping |
| [HHKB](https://github.com/iamcheyan/HHKB) | - | 0 | 276 | ✓ | inactive 276d, has content worth keeping |
| [karabiner](https://github.com/iamcheyan/karabiner) | - | 0 | 276 | ✓ | inactive 276d, has content worth keeping |
| [nano_cfg](https://github.com/iamcheyan/nano_cfg) | - | 0 | 275 | ✗ | inactive 275d, has content worth keeping |
| [PowerToys](https://github.com/iamcheyan/PowerToys) | - | 0 | 275 | ✗ | inactive 275d, has content worth keeping |
| [i3](https://github.com/iamcheyan/i3) | Shell | 0 | 246 | ✗ | inactive 246d, has content worth keeping |
| [titan2](https://github.com/iamcheyan/titan2) | Lua | 0 | 244 | ✓ | inactive 244d, has content worth keeping |
| [beautifullife.co.jp](https://github.com/iamcheyan/beautifullife.co.jp) 🔒 | HTML | 0 | 241 | ✓ | private repo — inactive 241d |
| [Wakan](https://github.com/iamcheyan/Wakan) | Python | 0 | 236 | ✗ | inactive 236d, has content worth keeping |
| [Honyaku](https://github.com/iamcheyan/Honyaku) | Python | 0 | 236 | ✓ | inactive 236d, has content worth keeping |
| [sbzr_tools](https://github.com/iamcheyan/sbzr_tools) | Python | 0 | 234 | ✓ | inactive 234d, has content worth keeping |
| [ZFVimIM](https://github.com/iamcheyan/ZFVimIM) | Vim Script | 7 | 233 | ✓ | inactive 233d, has content worth keeping |
| [dotfiles_old](https://github.com/iamcheyan/dotfiles_old) 🔒 | Shell | 0 | 232 | ✓ | private old dotfiles backup — superseded by chezmoi; archive, do not delete |
| [rime_old](https://github.com/iamcheyan/rime_old) 🔒 | Lua | 0 | 232 | ✓ | private old Rime config backup — superseded by rime/rime.xsb; archive, do not delete |
| [rime_sbzrjp](https://github.com/iamcheyan/rime_sbzrjp) | Lua | 0 | 232 | ✓ | inactive 232d, has content worth keeping |
| [sbzr](https://github.com/iamcheyan/sbzr) | Lua | 0 | 232 | ✓ | inactive 232d, has content worth keeping |
| [dotfiles_private](https://github.com/iamcheyan/dotfiles_private) 🔒 | Shell | 0 | 232 | ✓ | private repo — inactive 232d |
| [dotfiles_backups](https://github.com/iamcheyan/dotfiles_backups) 🔒 | CSS | 0 | 232 | ✓ | private dotfiles backup — historical value; archive, do not delete |
| [sway](https://github.com/iamcheyan/sway) | Shell | 0 | 229 | ✓ | inactive 229d, has content worth keeping |
| [sbzr.chrome.extension](https://github.com/iamcheyan/sbzr.chrome.extension) | JavaScript | 1 | 216 | ✓ | inactive 216d, has content worth keeping |
| [fudoki.chrome.extension](https://github.com/iamcheyan/fudoki.chrome.extension) | JavaScript | 5 | 215 | ✓ | inactive 215d, has content worth keeping |
| [HotelGuestLedger](https://github.com/iamcheyan/HotelGuestLedger) 🔒 | Python | 0 | 202 | ✓ | private repo — inactive 202d |
| [lmde7](https://github.com/iamcheyan/lmde7) | Shell | 0 | 194 | ✓ | inactive 194d, has content worth keeping |
| [private](https://github.com/iamcheyan/private) 🔒 | JavaScript | 0 | 194 | ✓ | private repo — inactive 194d |
| [workspace.openclaw.lcmd](https://github.com/iamcheyan/workspace.openclaw.lcmd) 🔒 | Shell | 0 | 192 | ✓ | private repo — inactive 192d |
| [blog](https://github.com/iamcheyan/blog) | CSS | 0 | 189 | ✓ | inactive 189d, has content worth keeping |
| [docs.twitter.openclaw.lcmd](https://github.com/iamcheyan/docs.twitter.openclaw.lcmd) 🔒 | Python | 0 | 189 | ✗ | private repo — inactive 189d |
| [openclaw-rescue-dashboard](https://github.com/iamcheyan/openclaw-rescue-dashboard) | HTML | 2 | 187 | ✓ | inactive 187d, has content worth keeping |
| [weather.openclaw.lcmd](https://github.com/iamcheyan/weather.openclaw.lcmd) | Python | 4 | 180 | ✓ | inactive 180d, has content worth keeping |

## 3. 有价值的 fork (unfork-keep)

| 仓库 | 上游 | ahead/behind | 距上次push(天) | stars | 理由 |
|---|---|---|---|---|---|
| [ChordVoxMini](https://github.com/iamcheyan/ChordVoxMini) | GravityPoet/ChordVox | 26/7 | 83 | 5 | own 26+ commits vs GravityPoet/ChordVox, pushed 83d ago |
| [VocoType-linux](https://github.com/iamcheyan/VocoType-linux) | LeonardNJU/VocoType-linux | 1/191 | 110 | 0 | own 1+ commits vs LeonardNJU/VocoType-linux, pushed 110d ago |
| [impala](https://github.com/iamcheyan/impala) | pythops/impala | 2/0 | 50 | 0 | own 2+ commits vs pythops/impala, pushed 50d ago |
| [labwc-plus](https://github.com/iamcheyan/labwc-plus) | labwc/labwc | 9/28 | 60 | 0 | own 9+ commits vs labwc/labwc, pushed 60d ago |
| [mir2x](https://github.com/iamcheyan/mir2x) | etorth/mir2x | 5/284 | 64 | 0 | own 5+ commits vs etorth/mir2x, pushed 64d ago |
| [oc](https://github.com/iamcheyan/oc) | anomalyco/opencode | 56/372 | 16 | 1 | own 56+ commits vs anomalyco/opencode, pushed 16d ago |
| [paipai](https://github.com/iamcheyan/paipai) | xiaozhua33/paipai-hackathon | 12/0 | 48 | 0 | own 12+ commits vs xiaozhua33/paipai-hackathon, pushed 48d ago |
| [pi](https://github.com/iamcheyan/pi) | earendil-works/pi | 20/1104 | 27 | 0 | own 20+ commits vs earendil-works/pi, pushed 27d ago |
| [pi-computer-use](https://github.com/iamcheyan/pi-computer-use) | injaneity/pi-computer-use | 2/56 | 32 | 4 | own 2+ commits vs injaneity/pi-computer-use, pushed 32d ago |
| [transparent-topbar](https://github.com/iamcheyan/transparent-topbar) | esorio/transparent-topbar | 2/0 | 111 | 0 | own 2+ commits vs esorio/transparent-topbar, pushed 111d ago |
| [uniai](https://github.com/iamcheyan/uniai) | quailyquaily/uniai | 1/44 | 104 | 0 | own 1+ commits vs quailyquaily/uniai, pushed 104d ago |
| [zellij-cb](https://github.com/iamcheyan/zellij-cb) | ndavd/zellij-cb | 17/5 | 61 | 1 | own 17+ commits vs ndavd/zellij-cb, pushed 61d ago |

## 4. 活跃自有项目 (keep)

（核心清单强制 keep：Zircon、Mir3-Research、mir3-website、mir2ei、Clawtter、chezmoi、dotfiles、hermes-backup、oh-my-desktop、sumika-*、svc-dashboard、terebi、rime、musubi、madobe、shirabe、sasayaki、pi-opencode-config-reader）

| 仓库 | 语言 | stars | 距上次push(天) | 理由 |
|---|---|---|---|---|
| [Mir3-Research](https://github.com/iamcheyan/Mir3-Research) | Python | 0 | 1 | core project (user-mandatory keep list) |
| [oh-my-desktop](https://github.com/iamcheyan/oh-my-desktop) | QML | 0 | 1 | core project (user-mandatory keep list) |
| [Zircon](https://github.com/iamcheyan/Zircon) | C# | 17 | 1 | core project (user-mandatory keep list) |
| [hermes-backup](https://github.com/iamcheyan/hermes-backup) 🔒 | Python | 0 | 1 | core project (user-mandatory keep list) |
| [chezmoi](https://github.com/iamcheyan/chezmoi) | Shell | 0 | 1 | core project (user-mandatory keep list) |
| [terebi](https://github.com/iamcheyan/terebi) | HTML | 11 | 2 | core project (user-mandatory keep list) |
| [Clawtter](https://github.com/iamcheyan/Clawtter) | Python | 29 | 2 | core project (user-mandatory keep list) |
| [dotfiles](https://github.com/iamcheyan/dotfiles) | Shell | 146 | 2 | core project (user-mandatory keep list) |
| [mir3-website](https://github.com/iamcheyan/mir3-website) | HTML | 0 | 2 | core project (user-mandatory keep list) |
| [svc-dashboard](https://github.com/iamcheyan/svc-dashboard) | Python | 1 | 3 | core project (user-mandatory keep list) |
| [mir2ei](https://github.com/iamcheyan/mir2ei) | HTML | 0 | 3 | core project (user-mandatory keep list) |
| [mir2ei-godot-sabak-map](https://github.com/iamcheyan/mir2ei-godot-sabak-map) | Python | 0 | 3 | active: pushed 3d ago |
| [sumika-shell-extensions](https://github.com/iamcheyan/sumika-shell-extensions) | QML | 0 | 4 | core project (user-mandatory keep list) |
| [sasayaki](https://github.com/iamcheyan/sasayaki) | - | 0 | 4 | core project (user-mandatory keep list) |
| [musubi](https://github.com/iamcheyan/musubi) | Go | 0 | 4 | core project (user-mandatory keep list) |
| [madobe](https://github.com/iamcheyan/madobe) | Go | 0 | 11 | core project (user-mandatory keep list) |
| [shirabe](https://github.com/iamcheyan/shirabe) | Go | 0 | 12 | core project (user-mandatory keep list) |
| [rime](https://github.com/iamcheyan/rime) | JavaScript | 16 | 14 | core project (user-mandatory keep list) |
| [iamcheyan.github.io](https://github.com/iamcheyan/iamcheyan.github.io) | JavaScript | 0 | 17 | active: pushed 17d ago |
| [sumika-website](https://github.com/iamcheyan/sumika-website) | HTML | 0 | 17 | core project (user-mandatory keep list) |
| [sumika-shell-modules](https://github.com/iamcheyan/sumika-shell-modules) | QML | 0 | 20 | core project (user-mandatory keep list) |
| [pi-opencode-config-reader](https://github.com/iamcheyan/pi-opencode-config-reader) | TypeScript | 9 | 26 | core project (user-mandatory keep list) |
| [pi-ralph](https://github.com/iamcheyan/pi-ralph) | TypeScript | 0 | 27 | active: pushed 27d ago |
| [pi-minimal](https://github.com/iamcheyan/pi-minimal) | TypeScript | 3 | 27 | active: pushed 27d ago |
| [TWM](https://github.com/iamcheyan/TWM) | Shell | 37 | 27 | active: pushed 27d ago |
| [pi-subagents](https://github.com/iamcheyan/pi-subagents) 🔒 | - | 0 | 27 | private repo — active (pushed 27d ago) |
| [pi-spawn](https://github.com/iamcheyan/pi-spawn) 🔒 | TypeScript | 0 | 27 | private repo — active (pushed 27d ago) |
| [pi-debug](https://github.com/iamcheyan/pi-debug) 🔒 | TypeScript | 0 | 27 | private repo — active (pushed 27d ago) |
| [pi-opencode2api](https://github.com/iamcheyan/pi-opencode2api) 🔒 | JavaScript | 0 | 27 | private repo — active (pushed 27d ago) |
| [opencode-vim](https://github.com/iamcheyan/opencode-vim) | TypeScript | 0 | 28 | active: pushed 28d ago |
| [ii](https://github.com/iamcheyan/ii) | QML | 0 | 54 | pushed 54d ago |
| [nas-app-cache](https://github.com/iamcheyan/nas-app-cache) | Shell | 0 | 60 | pushed 60d ago |
| [labwc-launcher](https://github.com/iamcheyan/labwc-launcher) | C | 0 | 62 | pushed 62d ago |
| [xinhua](https://github.com/iamcheyan/xinhua) 🔒 | Python | 0 | 70 | private repo — inactive 70d |
| [notes](https://github.com/iamcheyan/notes) | HTML | 0 | 96 | pushed 96d ago |
| [iamcheyan](https://github.com/iamcheyan/iamcheyan) | CSS | 1 | 101 | pushed 101d ago |
| [fudoki](https://github.com/iamcheyan/fudoki) | JavaScript | 891 | 102 | popular: 891 stars |
| [nas_album](https://github.com/iamcheyan/nas_album) | JavaScript | 21 | 110 | popular: 21 stars |
| [sbzr.nvim.im](https://github.com/iamcheyan/sbzr.nvim.im) | Vim Script | 0 | 122 | pushed 122d ago |
| [rime_sbzr_jp](https://github.com/iamcheyan/rime_sbzr_jp) | Lua | 16 | 276 | popular: 16 stars |
| [kotoba](https://github.com/iamcheyan/kotoba) | JavaScript | 31 | 299 | popular: 31 stars |

## 5. 本次补全的 description

共补全 **97** 个仓库的英文描述（非 archived、原描述为空），全部经 `gh repo edit --description` 写入并 API 回读验证成功。私有仓库描述已脱敏。

| 仓库 | 旧描述 | 新描述 |
|---|---|---|
| [AcrobatProDC_Linux_AppImage](https://github.com/iamcheyan/AcrobatProDC_Linux_AppImage) | *（空）* | Notes on packaging Adobe Acrobat Pro DC as a Linux AppImage |
| [Android16-Origin-Debian12-GUI](https://github.com/iamcheyan/Android16-Origin-Debian12-GUI) | *（空）* | Fork — scripts to run a Debian 12 desktop with VNC inside Android 16 Termux |
| [Clawtter](https://github.com/iamcheyan/Clawtter) | *（空）* | Sentient blog engine for OpenClaw agents: publishes agent memory/notes as a static site (twitter.iamcheyan.com) |
| [GO-TEST](https://github.com/iamcheyan/GO-TEST) | *（空）* | Simple single-file Go CLI playground (greet/calc/upper subcommands) for Go practice |
| [GuestHouse](https://github.com/iamcheyan/GuestHouse) 🔒 | *（空）* | (private — hidden) |
| [HHKB](https://github.com/iamcheyan/HHKB) | *（空）* | HHKB workspace: photos, Japanese manuals, drivers and macOS keymap configs |
| [Honyaku](https://github.com/iamcheyan/Honyaku) | *（空）* | Offline translation tool built on Argos Translate for Chinese/Japanese/English |
| [HotelGuestLedger](https://github.com/iamcheyan/HotelGuestLedger) 🔒 | *（空）* | (private — hidden) |
| [KKAB-github](https://github.com/iamcheyan/KKAB-github) | *（空）* | Kyoto minpaku (guesthouse) booking & management system: multilingual frontend with admin backend |
| [KamiNeko](https://github.com/iamcheyan/KamiNeko) | *（空）* | KamiNeko native app (Xcode) — macOS/iOS Markdown sticky notes companion |
| [KamiNeko-web](https://github.com/iamcheyan/KamiNeko-web) | *（空）* | KamiNeko online Markdown sticky-note editor: multi-tab, live preview, themes |
| [Kotoba-WXSS](https://github.com/iamcheyan/Kotoba-WXSS) | *（空）* | Kotoba vocabulary trainer WXSS styles — Japanese vocabulary practice web app styling |
| [MINIQuaily](https://github.com/iamcheyan/MINIQuaily) | *（空）* | Mini Flask notes app: Markdown + front-matter content with image upload |
| [MORPH](https://github.com/iamcheyan/MORPH) 🔒 | *（空）* | (private — hidden) |
| [Maibook](https://github.com/iamcheyan/Maibook) 🔒 | *（空）* | (private — hidden) |
| [MeloTTSBOOK](https://github.com/iamcheyan/MeloTTSBOOK) 🔒 | *（空）* | (private — hidden) |
| [Nano](https://github.com/iamcheyan/Nano) 🔒 | *（空）* | (private — hidden) |
| [PowerToys](https://github.com/iamcheyan/PowerToys) | *（空）* | Mirror checkout of Microsoft PowerToys sources |
| [SITES-BACKUPS](https://github.com/iamcheyan/SITES-BACKUPS) 🔒 | *（空）* | (private — hidden) |
| [TWM](https://github.com/iamcheyan/TWM) | *（空）* | Sway + i3 window manager dotfiles sharing Waybar/Kitty/Mako/Wofi with one-click init script |
| [Tools](https://github.com/iamcheyan/Tools) 🔒 | *（空）* | (private — hidden) |
| [Upscayl-Batch-CLI](https://github.com/iamcheyan/Upscayl-Batch-CLI) | *（空）* | Batch image upscaling via Upscayl's local Real-ESRGAN engine with Metal acceleration on Apple silicon |
| [VimQuest](https://github.com/iamcheyan/VimQuest) | *（空）* | Neovim plugin turning your codebase into an English vocabulary quiz injected as comments |
| [WOODS40](https://github.com/iamcheyan/WOODS40) | *（空）* | WOODS40 custom keyboard config share (WOODS_BASE / LAYOUT_45) for WOODSKB tool import |
| [Wakan](https://github.com/iamcheyan/Wakan) | *（空）* | Chinese input-method word banks: personal vocab plus Moran-shuangpin and Bohe-quanpin sets |
| [agent](https://github.com/iamcheyan/agent) 🔒 | *（空）* | (private — hidden) |
| [aigumi](https://github.com/iamcheyan/aigumi) | *（空）* | MultiChat: browser extension aggregating multiple logged-in AI web chats into one unified sidebar |
| [aliases](https://github.com/iamcheyan/aliases) | *（空）* | Categorized zsh alias collection (git, system, docker) designed as a dotfiles submodule or standalone |
| [automations](https://github.com/iamcheyan/automations) 🔒 | *（空）* | (private — hidden) |
| [beautifullife.co.jp](https://github.com/iamcheyan/beautifullife.co.jp) 🔒 | *（空）* | (private — hidden) |
| [blog](https://github.com/iamcheyan/blog) | *（空）* | Personal blog source (blog.iamcheyan.com) built with Pelican, auto-deployed to GitHub Pages |
| [chezmoi](https://github.com/iamcheyan/chezmoi) | *（空）* | Personal chezmoi-managed dotfiles (non-secret configs only); sensitive files live in a separate private vault |
| [config.openclaw.lcmd](https://github.com/iamcheyan/config.openclaw.lcmd) 🔒 | *（空）* | (private — hidden) |
| [cosmic-qs](https://github.com/iamcheyan/cosmic-qs) | *（空）* | Personal Quickshell config based on the illogical-impulse shell from dots-hyprland |
| [development.openclaw.lcmd](https://github.com/iamcheyan/development.openclaw.lcmd) 🔒 | *（空）* | (private — hidden) |
| [docs.twitter.openclaw.lcmd](https://github.com/iamcheyan/docs.twitter.openclaw.lcmd) 🔒 | *（空）* | (private — hidden) |
| [dotfiles_backups](https://github.com/iamcheyan/dotfiles_backups) 🔒 | *（空）* | (private — hidden) |
| [dotfiles_old](https://github.com/iamcheyan/dotfiles_old) 🔒 | *（空）* | (private — hidden) |
| [dotfiles_private](https://github.com/iamcheyan/dotfiles_private) 🔒 | *（空）* | (private — hidden) |
| [down2nas](https://github.com/iamcheyan/down2nas) | *（空）* | Empty placeholder repo (never initialized) — download-to-NAS idea |
| [faster-whisper-jpop](https://github.com/iamcheyan/faster-whisper-jpop) | *（空）* | J-Pop/City-Pop lyric transcriber: faster-whisper large-v3 with vocal separation and staged preprocessing |
| [fontconfig-zh-cn](https://github.com/iamcheyan/fontconfig-zh-cn) | *（空）* | Fork of ohmyarch/fontconfig-zh-cn — Chinese font rendering config for Linux |
| [fudoki.chrome.extension](https://github.com/iamcheyan/fudoki.chrome.extension) | *（空）* | Chrome extension adding furigana (kana readings) over kanji on any webpage |
| [fudu](https://github.com/iamcheyan/fudu) | *（空）* | Empty placeholder repo (never initialized) — no content pushed |
| [gentle-ai](https://github.com/iamcheyan/gentle-ai) | *（空）* | Fork of Gentleman-Programming/gentle-ai — ecosystem, frameworks and workflows for AI coding agents |
| [go_beautifulllife](https://github.com/iamcheyan/go_beautifulllife) | *（空）* | Static landing page for beautifulllife (GitHub Pages, CNAME) |
| [i3](https://github.com/iamcheyan/i3) | *（空）* | i3 window manager config with picom, scripts and wallpaper |
| [iamcheyan.github.io](https://github.com/iamcheyan/iamcheyan.github.io) | *（空）* | Personal website iamcheyan.com — trilingual (JA/ZH/EN) static portfolio (tetsuya/iamcheyan) |
| [jlpt-drill](https://github.com/iamcheyan/jlpt-drill) | *（空）* | OpenJLPT: open, fully offline JLPT question bank for N1-N5 drill practice (jlpt.iamcheyan.com) |
| [just-talk](https://github.com/iamcheyan/just-talk) | *（空）* | Fork of just-talk — PyQt6 push-to-talk voice input with global hotkeys and recording indicator |
| [karabiner](https://github.com/iamcheyan/karabiner) | *（空）* | Karabiner-Elements rules remapping a JIS keyboard to ANSI layout on macOS |
| [kazamo](https://github.com/iamcheyan/kazamo) | *（空）* | Voice-to-text for Linux: local speech recognition with SenseVoice and Paraformer, no cloud |
| [lmde7](https://github.com/iamcheyan/lmde7) | *（空）* | One-click LMDE 7 / Debian setup scripts: performance tuning, remote work and dev tooling bootstrap |
| [memory.openclaw.lcmd](https://github.com/iamcheyan/memory.openclaw.lcmd) 🔒 | *（空）* | (private — hidden) |
| [mir2ei](https://github.com/iamcheyan/mir2ei) | *（空）* | Mir2EI: complete static game wiki for Legend of Mir 3 EI 3.0 client + Mud3 server (544+ maps), on GitHub Pages |
| [mir3-website](https://github.com/iamcheyan/mir3-website) | *（空）* | Legend of Mir 3 fansite rebuild (mir3.17173.com) as a modern static wiki on GitHub Pages — mir3.iamcheyan.com |
| [miyako](https://github.com/iamcheyan/miyako) | *（空）* | Tauri web + Android app project (edge-to-edge UI, agent-assisted development) |
| [nano_cfg](https://github.com/iamcheyan/nano_cfg) | *（空）* | GNU nano editor configuration and syntax-highlighting settings (.nanorc) |
| [nas_album](https://github.com/iamcheyan/nas_album) | *（空）* | Lightweight NAS photo/video manager: multi-library scan, map view, duplicate cleanup (iPhoto-like) |
| [nixos-config](https://github.com/iamcheyan/nixos-config) | *（空）* | Personal NixOS flake configuration: hosts and modules for declarative system setup |
| [oh-my-desktop](https://github.com/iamcheyan/oh-my-desktop) | *（空）* | Sumika Shell: personal Omarchy + Quickshell desktop config with one-script install and extension modules |
| [openclaw-rescue-dashboard](https://github.com/iamcheyan/openclaw-rescue-dashboard) | *（空）* | Web emergency panel for OpenClaw: force-switch primary model and unlock stuck agent sessions |
| [opencode-vim](https://github.com/iamcheyan/opencode-vim) | *（空）* | opencode plugin adding full vim modal editing, LEADER menus, statusline and oceanblack theme via plugin API |
| [pi-minimal](https://github.com/iamcheyan/pi-minimal) | *（空）* | Minimalist REPL-style extension for the pi coding agent: cyan prompt, border-free UI, lean chrome |
| [pi-opencode2api](https://github.com/iamcheyan/pi-opencode2api) 🔒 | *（空）* | (private — hidden) |
| [pi-ralph](https://github.com/iamcheyan/pi-ralph) | *（空）* | Fork of snarktank/ralph — autonomous AI agent loop rebuilt as a pi coding-agent extension plugin |
| [pi-telegram](https://github.com/iamcheyan/pi-telegram) | *（空）* | Telegram bridge plugin for the pi coding agent: chat with pi from Telegram, with typing indicator |
| [pi4aws](https://github.com/iamcheyan/pi4aws) 🔒 | *（空）* | (private — hidden) |
| [private](https://github.com/iamcheyan/private) 🔒 | *（空）* | (private — hidden) |
| [qs](https://github.com/iamcheyan/qs) | *（空）* | TWM reborn: Niri/Sway/labwc/i3 dotfiles sharing Waybar/Kitty/Mako with one-click init script |
| [qs-cosmic](https://github.com/iamcheyan/qs-cosmic) | *（空）* | Quickshell config experiments targeting the COSMIC desktop (hypr/ii variants) |
| [rime.xsb](https://github.com/iamcheyan/rime.xsb) | *（空）* | Active Rime config: sbzr + Japanese romaji input schemes with multi-device sync and Nova editor theme |
| [rime_old](https://github.com/iamcheyan/rime_old) 🔒 | *（空）* | (private — hidden) |
| [rime_sbzr_jp](https://github.com/iamcheyan/rime_sbzr_jp) | *（空）* | Rime config collection: sbzr Chinese scheme plus Japanese romaji for fcitx5-rime |
| [rime_sbzrjp](https://github.com/iamcheyan/rime_sbzrjp) | *（空）* | Rime config collection: sbzr Chinese scheme plus Japanese romaji for fcitx5-rime |
| [sasayaki](https://github.com/iamcheyan/sasayaki) | *（空）* | Standalone Linux voice input: records, transcribes locally with SenseVoice, pastes into the focused app |
| [sbzr](https://github.com/iamcheyan/sbzr) | *（空）* | Rime input config centered on sbzr (声笔自然) shorthand Chinese scheme |
| [sbzr-chrome](https://github.com/iamcheyan/sbzr-chrome) | *（空）* | Early sbzr browser-input experiment using Google Input Tools |
| [sbzr.chrome.extension](https://github.com/iamcheyan/sbzr.chrome.extension) | *（空）* | SBZR input method as a Chrome/Edge extension: type sbzr codes in any web input box |
| [sbzr_tools](https://github.com/iamcheyan/sbzr_tools) | *（空）* | Standalone Python tool computing sbzr (声笔自然) input-method codes, stdlib only |
| [shirabe](https://github.com/iamcheyan/shirabe) | *（空）* | Per-keyboard remapping tool for Linux: turn any keyboard into a QMK/VIA-style custom layout |
| [svc-dashboard](https://github.com/iamcheyan/svc-dashboard) | *（空）* | Zero-dependency Python dashboard listing local TCP services plus load/CPU/memory/disk stats |
| [sway](https://github.com/iamcheyan/sway) | *（空）* | Sway dotfiles and usage docs based on Ruixi-rebirth/sway-dotfiles keybindings |
| [terebi](https://github.com/iamcheyan/terebi) | *（空）* | Web app that curates Japanese TV-station YouTube channels and plays their videos randomly |
| [titan2](https://github.com/iamcheyan/titan2) | *（空）* | Free FTP server notes with screenshots (Chinese) — legacy reference |
| [transparent-topbar](https://github.com/iamcheyan/transparent-topbar) | *（空）* | Fork of esorio/transparent-topbar — GNOME top bar made transparent, with smart mode and compact option |
| [tsumugu](https://github.com/iamcheyan/tsumugu) | *（空）* | Single-user NAS web tool: file browser plus YouTube audio downloader (FastAPI/HTMX/yt-dlp) |
| [veikin.com](https://github.com/iamcheyan/veikin.com) | *（空）* | Static site for veikin.com (GitHub Pages) |
| [vim-private](https://github.com/iamcheyan/vim-private) | *（空）* | Fork of e7h4n/vim-private — well-commented Vim config optimized for JS/HTML/CSS/Python/Shell |
| [weather.openclaw.lcmd](https://github.com/iamcheyan/weather.openclaw.lcmd) | *（空）* | OpenClaw weather agent: daily Telegram forecast with trend charts for your location |
| [win-notepad](https://github.com/iamcheyan/win-notepad) 🔒 | *（空）* | (private — hidden) |
| [workspace.openclaw.lcmd](https://github.com/iamcheyan/workspace.openclaw.lcmd) 🔒 | *（空）* | (private — hidden) |
| [xiaoshuo](https://github.com/iamcheyan/xiaoshuo) 🔒 | *（空）* | (private — hidden) |
| [yomu](https://github.com/iamcheyan/yomu) | *（空）* | Offline Japanese reading app for public-domain literature; web app plus Android APK (yomu.iamcheyan.com) |
| [yrbook](https://github.com/iamcheyan/yrbook) 🔒 | *（空）* | (private — hidden) |
| [zircon-legend-laucher](https://github.com/iamcheyan/zircon-legend-laucher) | *（空）* | Fork of raphaelcheung/zircon-legend-laucher — Zircon Mir3 game launcher (Chinese) |
| [zmk-config](https://github.com/iamcheyan/zmk-config) | *（空）* | Fork of bumony/zmk-config — ZMK firmware config and keymap for the Bumon42 keyboard |

## 6. 完整清单（按 pushedAt 降序）

| 仓库 | 私有 | fork | 上游 | 语言 | stars | push | 距push(天) | ahead/behind | README | 建议 |
|---|---|---|---|---|---|---|---|---|---|---|
| [Mir3-Research](https://github.com/iamcheyan/Mir3-Research) |  |  | - | Python | 0 | 2026-08-13 | 1 | - | ✓ | keep |
| [oh-my-desktop](https://github.com/iamcheyan/oh-my-desktop) |  |  | - | QML | 0 | 2026-08-13 | 1 | - | ✓ | keep |
| [Zircon](https://github.com/iamcheyan/Zircon) |  | 🍴 | Suprcode/Zircon | C# | 17 | 2026-08-13 | 1 | 567/0 | ✓ | keep |
| [hermes-backup](https://github.com/iamcheyan/hermes-backup) 🔒 | 🔒 |  | - | Python | 0 | 2026-08-13 | 1 | - | ✓ | keep |
| [chezmoi](https://github.com/iamcheyan/chezmoi) |  |  | - | Shell | 0 | 2026-08-13 | 1 | - | ✓ | keep |
| [terebi](https://github.com/iamcheyan/terebi) |  |  | - | HTML | 11 | 2026-08-12 | 2 | - | ✓ | keep |
| [Clawtter](https://github.com/iamcheyan/Clawtter) |  |  | - | Python | 29 | 2026-08-12 | 2 | - | ✓ | keep |
| [dotfiles](https://github.com/iamcheyan/dotfiles) |  |  | - | Shell | 146 | 2026-08-12 | 2 | - | ✓ | keep |
| [mir3-website](https://github.com/iamcheyan/mir3-website) |  |  | - | HTML | 0 | 2026-08-12 | 2 | - | ✓ | keep |
| [svc-dashboard](https://github.com/iamcheyan/svc-dashboard) |  |  | - | Python | 1 | 2026-08-11 | 3 | - | ✓ | keep |
| [mir2ei](https://github.com/iamcheyan/mir2ei) |  |  | - | HTML | 0 | 2026-08-11 | 3 | - | ✓ | keep |
| [mir2ei-godot-sabak-map](https://github.com/iamcheyan/mir2ei-godot-sabak-map) |  |  | - | Python | 0 | 2026-08-11 | 3 | - | ✓ | keep |
| [sumika-shell-extensions](https://github.com/iamcheyan/sumika-shell-extensions) |  |  | - | QML | 0 | 2026-08-10 | 4 | - | ✓ | keep |
| [sasayaki](https://github.com/iamcheyan/sasayaki) |  |  | - | - | 0 | 2026-08-10 | 4 | - | ✓ | keep |
| [musubi](https://github.com/iamcheyan/musubi) |  |  | - | Go | 0 | 2026-08-10 | 4 | - | ✓ | keep |
| [madobe](https://github.com/iamcheyan/madobe) |  |  | - | Go | 0 | 2026-08-03 | 11 | - | ✓ | keep |
| [shirabe](https://github.com/iamcheyan/shirabe) |  |  | - | Go | 0 | 2026-08-02 | 12 | - | ✓ | keep |
| [rime](https://github.com/iamcheyan/rime) |  |  | - | JavaScript | 16 | 2026-07-31 | 14 | - | ✓ | keep |
| [oc](https://github.com/iamcheyan/oc) |  | 🍴 | anomalyco/opencode | TypeScript | 1 | 2026-07-29 | 16 | 56/372 | ✓ | unfork-keep |
| [iamcheyan.github.io](https://github.com/iamcheyan/iamcheyan.github.io) |  |  | - | JavaScript | 0 | 2026-07-28 | 17 | - | ✓ | keep |
| [sumika-website](https://github.com/iamcheyan/sumika-website) |  |  | - | HTML | 0 | 2026-07-28 | 17 | - | ✗ | keep |
| [sumika-shell-modules](https://github.com/iamcheyan/sumika-shell-modules) |  |  | - | QML | 0 | 2026-07-25 | 20 | - | ✓ | keep |
| [pi-opencode-config-reader](https://github.com/iamcheyan/pi-opencode-config-reader) |  |  | - | TypeScript | 9 | 2026-07-19 | 26 | - | ✓ | keep |
| [pi](https://github.com/iamcheyan/pi) |  | 🍴 | earendil-works/pi | TypeScript | 0 | 2026-07-18 | 27 | 20/1104 | ✓ | unfork-keep |
| [pi-ralph](https://github.com/iamcheyan/pi-ralph) |  |  | - | TypeScript | 0 | 2026-07-18 | 27 | - | ✓ | keep |
| [pi-minimal](https://github.com/iamcheyan/pi-minimal) |  |  | - | TypeScript | 3 | 2026-07-18 | 27 | - | ✓ | keep |
| [TWM](https://github.com/iamcheyan/TWM) |  |  | - | Shell | 37 | 2026-07-18 | 27 | - | ✓ | keep |
| [pi-subagents](https://github.com/iamcheyan/pi-subagents) 🔒 | 🔒 |  | - | - | 0 | 2026-07-18 | 27 | - | ✗ | keep |
| [pi-spawn](https://github.com/iamcheyan/pi-spawn) 🔒 | 🔒 |  | - | TypeScript | 0 | 2026-07-18 | 27 | - | ✗ | keep |
| [pi-debug](https://github.com/iamcheyan/pi-debug) 🔒 | 🔒 |  | - | TypeScript | 0 | 2026-07-18 | 27 | - | ✓ | keep |
| [pi-opencode2api](https://github.com/iamcheyan/pi-opencode2api) 🔒 | 🔒 |  | - | JavaScript | 0 | 2026-07-18 | 27 | - | ✓ | keep |
| [opencode-vim](https://github.com/iamcheyan/opencode-vim) |  |  | - | TypeScript | 0 | 2026-07-17 | 28 | - | ✓ | keep |
| [pi-computer-use](https://github.com/iamcheyan/pi-computer-use) |  | 🍴 | injaneity/pi-computer-use | Rust | 4 | 2026-07-13 | 32 | 2/56 | ✓ | unfork-keep |
| [noctalia](https://github.com/iamcheyan/noctalia) |  | 🍴 | noctalia-dev/noctalia | C++ | 0 | 2026-07-12 | 33 | 0/817 | ✓ | delete-candidate |
| [nixos-config](https://github.com/iamcheyan/nixos-config) |  |  | - | Nix | 0 | 2026-07-09 | 36 | - | ✗ | describe-only |
| [Waybar](https://github.com/iamcheyan/Waybar) |  | 🍴 | Alexays/Waybar | C++ | 0 | 2026-07-03 | 42 | 0/795 | ✓ | delete-candidate |
| [gentle-ai](https://github.com/iamcheyan/gentle-ai) |  | 🍴 | Gentleman-Programming/gentle-ai | Go | 0 | 2026-06-27 | 48 | 0/1703 | ✓ | delete-candidate |
| [paipai](https://github.com/iamcheyan/paipai) |  | 🍴 | xiaozhua33/paipai-hackathon | TypeScript | 0 | 2026-06-27 | 48 | 12/0 | ✓ | unfork-keep |
| [rime.xsb](https://github.com/iamcheyan/rime.xsb) |  |  | - | JavaScript | 0 | 2026-06-26 | 49 | - | ✓ | describe-only |
| [qs](https://github.com/iamcheyan/qs) |  |  | - | Shell | 0 | 2026-06-26 | 49 | - | ✓ | describe-only |
| [aliases](https://github.com/iamcheyan/aliases) |  |  | - | Shell | 0 | 2026-06-26 | 49 | - | ✓ | describe-only |
| [VimQuest](https://github.com/iamcheyan/VimQuest) |  |  | - | Lua | 0 | 2026-06-26 | 49 | - | ✓ | describe-only |
| [impala](https://github.com/iamcheyan/impala) |  | 🍴 | pythops/impala | Rust | 0 | 2026-06-25 | 50 | 2/0 | ✓ | unfork-keep |
| [omarchy](https://github.com/iamcheyan/omarchy) |  | 🍴 | basecamp/omarchy | Shell | 0 | 2026-06-22 | 53 | 0/1684 | ✓ | delete-candidate |
| [qs-cosmic](https://github.com/iamcheyan/qs-cosmic) |  |  | - | QML | 0 | 2026-06-22 | 53 | - | ✗ | describe-only |
| [ii](https://github.com/iamcheyan/ii) |  |  | - | QML | 0 | 2026-06-21 | 54 | - | ✗ | keep |
| [cosmic-qs](https://github.com/iamcheyan/cosmic-qs) |  |  | - | QML | 0 | 2026-06-19 | 56 | - | ✓ | describe-only |
| [pi4aws](https://github.com/iamcheyan/pi4aws) 🔒 | 🔒 |  | - | - | 0 | 2026-06-17 | 58 | - | ✗ | delete-candidate |
| [kazamo](https://github.com/iamcheyan/kazamo) |  |  | - | Rust | 0 | 2026-06-16 | 59 | - | ✓ | describe-only |
| [nas-app-cache](https://github.com/iamcheyan/nas-app-cache) |  |  | - | Shell | 0 | 2026-06-15 | 60 | - | ✓ | keep |
| [labwc-plus](https://github.com/iamcheyan/labwc-plus) |  | 🍴 | labwc/labwc | C | 0 | 2026-06-15 | 60 | 9/28 | ✓ | unfork-keep |
| [zellij-cb](https://github.com/iamcheyan/zellij-cb) |  | 🍴 | ndavd/zellij-cb | Rust | 1 | 2026-06-14 | 61 | 17/5 | ✓ | unfork-keep |
| [labwc-launcher](https://github.com/iamcheyan/labwc-launcher) |  |  | - | C | 0 | 2026-06-13 | 62 | - | ✗ | keep |
| [yrbook](https://github.com/iamcheyan/yrbook) 🔒 | 🔒 |  | - | Python | 0 | 2026-06-13 | 62 | - | ✓ | describe-only |
| [mir2x](https://github.com/iamcheyan/mir2x) |  | 🍴 | etorth/mir2x | C++ | 0 | 2026-06-11 | 64 | 5/284 | ✓ | unfork-keep |
| [tsumugu](https://github.com/iamcheyan/tsumugu) |  |  | - | HTML | 0 | 2026-06-05 | 70 | - | ✗ | describe-only |
| [down2nas](https://github.com/iamcheyan/down2nas) |  |  | - | - | 0 | 2026-06-05 | 70 | - | ✗ | delete-candidate |
| [xinhua](https://github.com/iamcheyan/xinhua) 🔒 | 🔒 |  | - | Python | 0 | 2026-06-05 | 70 | - | ✓ | keep |
| [miyako](https://github.com/iamcheyan/miyako) |  |  | - | TypeScript | 0 | 2026-06-04 | 71 | - | ✗ | describe-only |
| [pi-telegram](https://github.com/iamcheyan/pi-telegram) |  |  | - | TypeScript | 0 | 2026-06-03 | 72 | - | ✓ | describe-only |
| [hyprquickframe](https://github.com/iamcheyan/hyprquickframe) |  | 🍴 | Ronin-CK/HyprQuickFrame | QML | 0 | 2026-06-01 | 74 | 0/0 | ✓ | delete-candidate |
| [fudu](https://github.com/iamcheyan/fudu) |  |  | - | - | 0 | 2026-05-31 | 75 | - | ✗ | delete-candidate |
| [aigumi](https://github.com/iamcheyan/aigumi) |  |  | - | TypeScript | 0 | 2026-05-30 | 76 | - | ✓ | describe-only |
| [ChordVoxMini](https://github.com/iamcheyan/ChordVoxMini) |  | 🍴 | GravityPoet/ChordVox | JavaScript | 5 | 2026-05-23 | 83 | 26/7 | ✓ | unfork-keep |
| [hunk](https://github.com/iamcheyan/hunk) |  | 🍴 | modem-dev/hunk | TypeScript | 0 | 2026-05-11 | 95 | 0/265 | ✓ | delete-candidate |
| [cc-switch-cli](https://github.com/iamcheyan/cc-switch-cli) |  | 🍴 | SaladDay/cc-switch-cli | Rust | 0 | 2026-05-10 | 96 | 0/407 | ✓ | delete-candidate |
| [opencode-studio](https://github.com/iamcheyan/opencode-studio) |  | 🍴 | Microck/opencode-studio | TypeScript | 0 | 2026-05-10 | 96 | 0/39 | ✓ | delete-candidate |
| [notes](https://github.com/iamcheyan/notes) |  |  | - | HTML | 0 | 2026-05-10 | 96 | - | ✗ | keep |
| [faster-whisper-jpop](https://github.com/iamcheyan/faster-whisper-jpop) |  |  | - | Python | 1 | 2026-05-08 | 98 | - | ✓ | describe-only |
| [yomu](https://github.com/iamcheyan/yomu) |  |  | - | JavaScript | 0 | 2026-05-08 | 98 | - | ✓ | describe-only |
| [agent](https://github.com/iamcheyan/agent) 🔒 | 🔒 |  | - | - | 0 | 2026-05-07 | 99 | - | ✗ | delete-candidate |
| [GO-TEST](https://github.com/iamcheyan/GO-TEST) |  |  | - | Go | 0 | 2026-05-05 | 101 | - | ✓ | describe-only |
| [jlpt-drill](https://github.com/iamcheyan/jlpt-drill) |  |  | - | JavaScript | 0 | 2026-05-05 | 101 | - | ✓ | describe-only |
| [iamcheyan](https://github.com/iamcheyan/iamcheyan) |  |  | - | CSS | 1 | 2026-05-05 | 101 | - | ✓ | keep |
| [fudoki](https://github.com/iamcheyan/fudoki) |  |  | - | JavaScript | 891 | 2026-05-04 | 102 | - | ✓ | keep |
| [mistermorph](https://github.com/iamcheyan/mistermorph) |  | 🍴 | quailyquaily/mistermorph | Go | 0 | 2026-05-03 | 103 | 0/284 | ✓ | delete-candidate |
| [con-terminal](https://github.com/iamcheyan/con-terminal) |  | 🍴 | nowledge-co/con-terminal | Rust | 0 | 2026-05-03 | 103 | 0/552 | ✓ | delete-candidate |
| [openWarp](https://github.com/iamcheyan/openWarp) |  | 🍴 | zerx-lab/zap | Rust | 0 | 2026-05-02 | 104 | 0/703 | ✓ | delete-candidate |
| [uniai](https://github.com/iamcheyan/uniai) |  | 🍴 | quailyquaily/uniai | Go | 0 | 2026-05-02 | 104 | 1/44 | ✓ | unfork-keep |
| [SITES-BACKUPS](https://github.com/iamcheyan/SITES-BACKUPS) 🔒 | 🔒 |  | - | PHP | 0 | 2026-04-29 | 107 | - | ✓ | describe-only |
| [tolaria](https://github.com/iamcheyan/tolaria) |  | 🍴 | refactoringhq/tolaria | TypeScript | 0 | 2026-04-28 | 108 | 0/1495 | ✓ | delete-candidate |
| [nas_album](https://github.com/iamcheyan/nas_album) |  |  | - | JavaScript | 21 | 2026-04-26 | 110 | - | ✓ | keep |
| [fcitx5-vinput](https://github.com/iamcheyan/fcitx5-vinput) |  | 🍴 | xifan2333/fcitx5-vinput | C++ | 0 | 2026-04-26 | 110 | 0/80 | ✓ | delete-candidate |
| [VocoType-linux](https://github.com/iamcheyan/VocoType-linux) |  | 🍴 | LeonardNJU/VocoType-linux | Python | 0 | 2026-04-26 | 110 | 1/191 | ✓ | unfork-keep |
| [transparent-topbar](https://github.com/iamcheyan/transparent-topbar) |  | 🍴 | esorio/transparent-topbar | JavaScript | 0 | 2026-04-25 | 111 | 2/0 | ✓ | unfork-keep |
| [opencode2api](https://github.com/iamcheyan/opencode2api) |  | 🍴 | TiaraBasori/OpenCode2API | JavaScript | 0 | 2026-04-18 | 118 | 0/21 | ✓ | delete-candidate |
| [memory.openclaw.lcmd](https://github.com/iamcheyan/memory.openclaw.lcmd) 🔒 | 🔒 |  | - | HTML | 0 | 2026-04-14 | 122 | - | ✓ | describe-only |
| [development.openclaw.lcmd](https://github.com/iamcheyan/development.openclaw.lcmd) 🔒 | 🔒 |  | - | Python | 0 | 2026-04-14 | 122 | - | ✓ | describe-only |
| [sbzr.nvim.im](https://github.com/iamcheyan/sbzr.nvim.im) |  |  | - | Vim Script | 0 | 2026-04-14 | 122 | - | ✓ | keep |
| [MORPH](https://github.com/iamcheyan/MORPH) 🔒 | 🔒 |  | - | PowerShell | 0 | 2026-04-12 | 124 | - | ✓ | describe-only |
| [automations](https://github.com/iamcheyan/automations) 🔒 | 🔒 |  | - | Python | 0 | 2026-04-11 | 125 | - | ✓ | describe-only |
| [wechat-selkies](https://github.com/iamcheyan/wechat-selkies) |  | 🍴 | nickrunning/wechat-selkies | Python | 0 | 2026-04-07 | 129 | 0/15 | ✓ | delete-candidate |
| [win-notepad](https://github.com/iamcheyan/win-notepad) 🔒 | 🔒 |  | - | Python | 0 | 2026-04-05 | 131 | - | ✓ | describe-only |
| [config.openclaw.lcmd](https://github.com/iamcheyan/config.openclaw.lcmd) 🔒 | 🔒 |  | - | Python | 0 | 2026-04-04 | 132 | - | ✓ | describe-only |
| [Upscayl-Batch-CLI](https://github.com/iamcheyan/Upscayl-Batch-CLI) |  |  | - | Python | 1 | 2026-03-17 | 150 | - | ✓ | describe-only |
| [just-talk](https://github.com/iamcheyan/just-talk) |  | 🍴 | whoamihappyhacking/just-talk | Python | 0 | 2026-03-06 | 161 | 0/8 | ✓ | delete-candidate |
| [weather.openclaw.lcmd](https://github.com/iamcheyan/weather.openclaw.lcmd) |  |  | - | Python | 4 | 2026-02-15 | 180 | - | ✓ | archive |
| [openclaw-rescue-dashboard](https://github.com/iamcheyan/openclaw-rescue-dashboard) |  |  | - | HTML | 2 | 2026-02-08 | 187 | - | ✓ | archive |
| [blog](https://github.com/iamcheyan/blog) |  |  | - | CSS | 0 | 2026-02-06 | 189 | - | ✓ | archive |
| [docs.twitter.openclaw.lcmd](https://github.com/iamcheyan/docs.twitter.openclaw.lcmd) 🔒 | 🔒 |  | - | Python | 0 | 2026-02-06 | 189 | - | ✗ | archive |
| [workspace.openclaw.lcmd](https://github.com/iamcheyan/workspace.openclaw.lcmd) 🔒 | 🔒 |  | - | Shell | 0 | 2026-02-03 | 192 | - | ✓ | archive |
| [lmde7](https://github.com/iamcheyan/lmde7) |  |  | - | Shell | 0 | 2026-02-01 | 194 | - | ✓ | archive |
| [private](https://github.com/iamcheyan/private) 🔒 | 🔒 |  | - | JavaScript | 0 | 2026-02-01 | 194 | - | ✓ | archive |
| [HotelGuestLedger](https://github.com/iamcheyan/HotelGuestLedger) 🔒 | 🔒 |  | - | Python | 0 | 2026-01-24 | 202 | - | ✓ | archive |
| [Humanizer-zh](https://github.com/iamcheyan/Humanizer-zh) |  | 🍴 | op7418/Humanizer-zh | - | 0 | 2026-01-19 | 207 | 0/0 | ✓ | delete-candidate |
| [fudoki.chrome.extension](https://github.com/iamcheyan/fudoki.chrome.extension) |  |  | - | JavaScript | 5 | 2026-01-11 | 215 | - | ✓ | archive |
| [sbzr.chrome.extension](https://github.com/iamcheyan/sbzr.chrome.extension) |  |  | - | JavaScript | 1 | 2026-01-10 | 216 | - | ✓ | archive |
| [Android16-Origin-Debian12-GUI](https://github.com/iamcheyan/Android16-Origin-Debian12-GUI) |  | 🍴 | xlzhen-940218/Android16-Origin-Debian12-GUI | Shell | 0 | 2025-12-30 | 227 | 0/12 | ✓ | delete-candidate |
| [sway](https://github.com/iamcheyan/sway) |  |  | - | Shell | 0 | 2025-12-28 | 229 | - | ✓ | archive |
| [dotfiles_old](https://github.com/iamcheyan/dotfiles_old) 🔒 | 🔒 |  | - | Shell | 0 | 2025-12-25 | 232 | - | ✓ | archive |
| [rime_old](https://github.com/iamcheyan/rime_old) 🔒 | 🔒 |  | - | Lua | 0 | 2025-12-25 | 232 | - | ✓ | archive |
| [rime_sbzrjp](https://github.com/iamcheyan/rime_sbzrjp) |  |  | - | Lua | 0 | 2025-12-25 | 232 | - | ✓ | archive |
| [sbzr](https://github.com/iamcheyan/sbzr) |  |  | - | Lua | 0 | 2025-12-25 | 232 | - | ✓ | archive |
| [dotfiles_private](https://github.com/iamcheyan/dotfiles_private) 🔒 | 🔒 |  | - | Shell | 0 | 2025-12-25 | 232 | - | ✓ | archive |
| [dotfiles_backups](https://github.com/iamcheyan/dotfiles_backups) 🔒 | 🔒 |  | - | CSS | 0 | 2025-12-25 | 232 | - | ✓ | archive |
| [ZFVimIM](https://github.com/iamcheyan/ZFVimIM) |  | 🍴 | ZSaberLv0/ZFVimIM | Vim Script | 7 | 2025-12-24 | 233 | 147/45 | ✓ | archive |
| [sbzr_tools](https://github.com/iamcheyan/sbzr_tools) |  |  | - | Python | 0 | 2025-12-23 | 234 | - | ✓ | archive |
| [Wakan](https://github.com/iamcheyan/Wakan) |  |  | - | Python | 0 | 2025-12-21 | 236 | - | ✗ | archive |
| [Honyaku](https://github.com/iamcheyan/Honyaku) |  |  | - | Python | 0 | 2025-12-21 | 236 | - | ✓ | archive |
| [beautifullife.co.jp](https://github.com/iamcheyan/beautifullife.co.jp) 🔒 | 🔒 |  | - | HTML | 0 | 2025-12-16 | 241 | - | ✓ | archive |
| [titan2](https://github.com/iamcheyan/titan2) |  |  | - | Lua | 0 | 2025-12-13 | 244 | - | ✓ | archive |
| [i3](https://github.com/iamcheyan/i3) |  |  | - | Shell | 0 | 2025-12-11 | 246 | - | ✗ | archive |
| [nano_cfg](https://github.com/iamcheyan/nano_cfg) |  |  | - | - | 0 | 2025-11-12 | 275 | - | ✗ | archive |
| [PowerToys](https://github.com/iamcheyan/PowerToys) |  |  | - | - | 0 | 2025-11-12 | 275 | - | ✗ | archive |
| [HHKB](https://github.com/iamcheyan/HHKB) |  |  | - | - | 0 | 2025-11-11 | 276 | - | ✓ | archive |
| [karabiner](https://github.com/iamcheyan/karabiner) |  |  | - | - | 0 | 2025-11-11 | 276 | - | ✓ | archive |
| [rime_sbzr_jp](https://github.com/iamcheyan/rime_sbzr_jp) |  |  | - | Lua | 16 | 2025-11-11 | 276 | - | ✓ | keep |
| [sbzr-chrome](https://github.com/iamcheyan/sbzr-chrome) |  |  | - | JavaScript | 0 | 2025-11-06 | 281 | - | ✗ | archive |
| [go_beautifulllife](https://github.com/iamcheyan/go_beautifulllife) |  |  | - | HTML | 0 | 2025-11-03 | 284 | - | ✗ | archive |
| [Kotoba-WXSS](https://github.com/iamcheyan/Kotoba-WXSS) |  |  | - | JavaScript | 0 | 2025-10-31 | 287 | - | ✓ | archive |
| [zmk-config](https://github.com/iamcheyan/zmk-config) |  | 🍴 | bumony/zmk-config | C | 0 | 2025-10-28 | 290 | 51/33 | ✓ | archive |
| [WOODS40](https://github.com/iamcheyan/WOODS40) |  |  | - | HTML | 2 | 2025-10-25 | 293 | - | ✓ | archive |
| [kotoba](https://github.com/iamcheyan/kotoba) |  |  | - | JavaScript | 31 | 2025-10-19 | 299 | - | ✓ | keep |
| [veikin.com](https://github.com/iamcheyan/veikin.com) |  |  | - | CSS | 0 | 2025-10-18 | 300 | - | ✗ | archive |
| [Yomimo](https://github.com/iamcheyan/Yomimo) |  |  | - | HTML | 0 | 2025-10-14 | 304 | - | ✓ | archive |
| [Nano](https://github.com/iamcheyan/Nano) 🔒 | 🔒 |  | - | HTML | 0 | 2025-10-10 | 308 | - | ✓ | archive |
| [KKAB-github](https://github.com/iamcheyan/KKAB-github) |  |  | - | HTML | 0 | 2025-09-30 | 318 | - | ✓ | archive |
| [MINIQuaily](https://github.com/iamcheyan/MINIQuaily) |  |  | - | JavaScript | 0 | 2025-09-29 | 319 | - | ✗ | archive |
| [KamiNeko-web](https://github.com/iamcheyan/KamiNeko-web) |  |  | - | JavaScript | 0 | 2025-09-29 | 319 | - | ✓ | archive |
| [GuestHouse](https://github.com/iamcheyan/GuestHouse) 🔒 | 🔒 |  | - | HTML | 0 | 2025-09-27 | 321 | - | ✓ | archive |
| [Maibook](https://github.com/iamcheyan/Maibook) 🔒 | 🔒 |  | - | HTML | 0 | 2025-09-25 | 323 | - | ✓ | archive |
| [Tools](https://github.com/iamcheyan/Tools) 🔒 | 🔒 |  | - | Python | 0 | 2025-09-25 | 323 | - | ✗ | archive |
| [paopao-ce](https://github.com/iamcheyan/paopao-ce) |  | 🍴 | rocboss/paopao-ce | Go | 0 | 2025-09-22 | 326 | 0/71 | ✓ | delete-candidate |
| [MeloTTSBOOK](https://github.com/iamcheyan/MeloTTSBOOK) 🔒 | 🔒 |  | - | Python | 0 | 2025-09-08 | 340 | - | ✓ | archive |
| [KamiNeko](https://github.com/iamcheyan/KamiNeko) |  |  | - | Swift | 0 | 2025-09-07 | 341 | - | ✓ | archive |
| [MobileTransfer](https://github.com/iamcheyan/MobileTransfer) |  | 🍴 | Lakr233/MobileTransfer | Swift | 1 | 2025-09-05 | 343 | 11/9 | ✓ | archive |
| [xiaoshuo](https://github.com/iamcheyan/xiaoshuo) 🔒 | 🔒 |  | - | Python | 0 | 2025-08-24 | 355 | - | ✓ | archive |
| [cursor](https://github.com/iamcheyan/cursor) |  |  | - | Shell | 4 | 2025-07-11 | 399 | - | ✓ | archive |
| [zircon-legend-laucher](https://github.com/iamcheyan/zircon-legend-laucher) |  | 🍴 | raphaelcheung/zircon-legend-laucher | C# | 0 | 2025-04-23 | 478 | 0/0 | ✓ | delete-candidate |
| [azik-roman-table](https://github.com/iamcheyan/azik-roman-table) |  | 🍴 | toriwasa/azik-roman-table | - | 1 | 2025-01-12 | 579 | 0/0 | ✓ | delete-candidate |
| [7z-for-Linux](https://github.com/iamcheyan/7z-for-Linux) |  |  | - | Shell | 2 | 2024-11-17 | 635 | - | ✓ | archive |
| [AcrobatProDC_Linux_AppImage](https://github.com/iamcheyan/AcrobatProDC_Linux_AppImage) |  |  | - | - | 0 | 2024-11-16 | 636 | - | ✓ | archive |
| [tidy-sddm](https://github.com/iamcheyan/tidy-sddm) |  | 🍴 | loadfred/tidy-sddm | QML | 0 | 2024-11-14 | 638 | 0/0 | ✓ | delete-candidate |
| [OrchideaDock](https://github.com/iamcheyan/OrchideaDock) |  |  | - | CSS | 6 | 2024-10-09 | 674 | - | ✓ | archive |
| [folderify](https://github.com/iamcheyan/folderify) |  | 🍴 | lgarron/folderify | Rust | 0 | 2024-09-27 | 686 | 0/44 | ✓ | delete-candidate |
| [distro-grub-themes](https://github.com/iamcheyan/distro-grub-themes) |  | 🍴 | AdisonCavani/distro-grub-themes | Nix | 0 | 2024-09-01 | 712 | 0/7 | ✓ | delete-candidate |
| [MirForGodot](https://github.com/iamcheyan/MirForGodot) |  | 🍴 | makeryangcom/MirForGodot | Vue | 0 | 2024-08-20 | 724 | 0/0 | ✓ | delete-candidate |
| [Pelican-Random-Article-Loader-Plugin](https://github.com/iamcheyan/Pelican-Random-Article-Loader-Plugin) |  |  | - | JavaScript | 0 | 2023-11-25 | 993 | - | ✓ | archive |
| [simple_translation](https://github.com/iamcheyan/simple_translation) |  |  | - | Python | 0 | 2023-11-21 | 997 | - | ✓ | archive |
| [Sanhua-cat-Makedown2Html](https://github.com/iamcheyan/Sanhua-cat-Makedown2Html) |  |  | - | - | 0 | 2023-10-04 | 1045 | - | ✓ | archive |
| [Simplified-AZIK](https://github.com/iamcheyan/Simplified-AZIK) |  | 🍴 | yuru7/Simplified-AZIK | - | 0 | 2022-07-19 | 1487 | 0/0 | ✓ | delete-candidate |
| [rime-double-pinyin](https://github.com/iamcheyan/rime-double-pinyin) |  | 🍴 | rime/rime-double-pinyin | - | 0 | 2019-11-25 | 2454 | 0/5 | ✓ | delete-candidate |
| [fonts](https://github.com/iamcheyan/fonts) |  | 🍴 | owent-utils/font | Python | 0 | 2017-04-20 | 3403 | 0/0 | ✓ | delete-candidate |
| [fontconfig-zh-cn](https://github.com/iamcheyan/fontconfig-zh-cn) |  | 🍴 | ohmyarch/fontconfig-zh-cn | - | 0 | 2017-04-11 | 3412 | 0/0 | ✓ | delete-candidate |
| [panel_for_zhihu](https://github.com/iamcheyan/panel_for_zhihu) |  |  | - | JavaScript | 2 | 2016-12-30 | 3514 | - | ✓ | archive |
| [jquery-color](https://github.com/iamcheyan/jquery-color) |  | 🍴 | jquery/jquery-color | JavaScript | 0 | 2013-10-02 | 4699 | 0/157 | ✓ | delete-candidate |
| [jQuery-menu-aim](https://github.com/iamcheyan/jQuery-menu-aim) |  | 🍴 | kamens/jQuery-menu-aim | JavaScript | 0 | 2013-03-06 | 4909 | 0/19 | ✓ | delete-candidate |
| [MacVim](https://github.com/iamcheyan/MacVim) |  |  | - | Vim Script | 6 | 2012-07-05 | 5153 | - | ✓ | archive |
| [iamcheyan.com-for-wordpress](https://github.com/iamcheyan/iamcheyan.com-for-wordpress) |  |  | - | PHP | 2 | 2012-06-29 | 5159 | - | ✓ | archive |
| [pentadactylrc](https://github.com/iamcheyan/pentadactylrc) |  |  | - | JavaScript | 3 | 2012-06-29 | 5159 | - | ✓ | archive |
| [vim-private](https://github.com/iamcheyan/vim-private) |  | 🍴 | e7h4n/vim-private | Vim Script | 1 | 2012-06-28 | 5160 | 0/17 | ✓ | delete-candidate |
| [leng](https://github.com/iamcheyan/leng) |  |  | - | JavaScript | 1 | 2012-06-26 | 5162 | - | ✗ | archive |
| [css-auto-reload](https://github.com/iamcheyan/css-auto-reload) |  | 🍴 | allenm/css-auto-reload | JavaScript | 1 | 2012-06-07 | 5181 | 0/15 | ✓ | delete-candidate |
| [kissy](https://github.com/iamcheyan/kissy) |  | 🍴 | kissyteam/kissy | JavaScript | 1 | 2012-04-05 | 5244 | 0/2277 | ✓ | delete-candidate |
| [Markdown-Syntax-CN](https://github.com/iamcheyan/Markdown-Syntax-CN) |  | 🍴 | riku/Markdown-Syntax-CN | Perl | 1 | 2012-04-03 | 5246 | 5/47 | ✓ | archive |
| [sublime-gbk](https://github.com/iamcheyan/sublime-gbk) |  | 🍴 | akira-cn/sublime-gbk | Python | 1 | 2012-03-13 | 5267 | 1/10 | ✓ | archive |
| [Alice](https://github.com/iamcheyan/Alice) |  | 🍴 | sofish/Alice | JavaScript | 1 | 2012-01-07 | 5333 | 0/22 | ✓ | delete-candidate |

## 7. 操作建议（手动执行）

以下命令**均未执行**，仅供确认后手动运行。delete 全部注释，逐条放开。

### 归档（低风险，可逆）

```bash
gh repo archive iamcheyan/7z-for-Linux --yes  # inactive 635d, has content worth keeping
gh repo archive iamcheyan/AcrobatProDC_Linux_AppImage --yes  # notes-only repo (README stub, 0 KB content), inactive 637d
gh repo archive iamcheyan/GuestHouse --yes  # private repo — inactive 321d
gh repo archive iamcheyan/HHKB --yes  # inactive 276d, has content worth keeping
gh repo archive iamcheyan/Honyaku --yes  # inactive 236d, has content worth keeping
gh repo archive iamcheyan/HotelGuestLedger --yes  # private repo — inactive 202d
gh repo archive iamcheyan/KKAB-github --yes  # inactive 318d, has content worth keeping
gh repo archive iamcheyan/KamiNeko --yes  # inactive 341d, has content worth keeping
gh repo archive iamcheyan/KamiNeko-web --yes  # inactive 319d, has content worth keeping
gh repo archive iamcheyan/Kotoba-WXSS --yes  # inactive 287d, has content worth keeping
gh repo archive iamcheyan/MINIQuaily --yes  # inactive 319d, has content worth keeping
gh repo archive iamcheyan/MacVim --yes  # long dormant (5153d) but has content
gh repo archive iamcheyan/Maibook --yes  # private repo — inactive 323d
gh repo archive iamcheyan/Markdown-Syntax-CN --yes  # long dormant (5246d) but has content
gh repo archive iamcheyan/MeloTTSBOOK --yes  # private repo — inactive 340d
gh repo archive iamcheyan/MobileTransfer --yes  # inactive 343d, has content worth keeping
gh repo archive iamcheyan/Nano --yes  # private repo — inactive 308d
gh repo archive iamcheyan/OrchideaDock --yes  # inactive 674d, has content worth keeping
gh repo archive iamcheyan/Pelican-Random-Article-Loader-Plugin --yes  # long dormant (993d) but has content
gh repo archive iamcheyan/PowerToys --yes  # inactive 275d, has content worth keeping
gh repo archive iamcheyan/Sanhua-cat-Makedown2Html --yes  # long dormant (1045d) but has content
gh repo archive iamcheyan/Tools --yes  # private repo — inactive 323d
gh repo archive iamcheyan/WOODS40 --yes  # inactive 293d, has content worth keeping
gh repo archive iamcheyan/Wakan --yes  # inactive 236d, has content worth keeping
gh repo archive iamcheyan/Yomimo --yes  # inactive 304d, has content worth keeping
gh repo archive iamcheyan/ZFVimIM --yes  # inactive 233d, has content worth keeping
gh repo archive iamcheyan/beautifullife.co.jp --yes  # private repo — inactive 241d
gh repo archive iamcheyan/blog --yes  # inactive 189d, has content worth keeping
gh repo archive iamcheyan/cursor --yes  # inactive 399d, has content worth keeping
gh repo archive iamcheyan/docs.twitter.openclaw.lcmd --yes  # private repo — inactive 189d
gh repo archive iamcheyan/dotfiles_backups --yes  # private dotfiles backup — historical value; archive, do not delete
gh repo archive iamcheyan/dotfiles_old --yes  # private old dotfiles backup — superseded by chezmoi; archive, do not delete
gh repo archive iamcheyan/dotfiles_private --yes  # private repo — inactive 232d
gh repo archive iamcheyan/fudoki.chrome.extension --yes  # inactive 215d, has content worth keeping
gh repo archive iamcheyan/go_beautifulllife --yes  # inactive 284d, has content worth keeping
gh repo archive iamcheyan/i3 --yes  # inactive 246d, has content worth keeping
gh repo archive iamcheyan/iamcheyan.com-for-wordpress --yes  # long dormant (5159d) but has content
gh repo archive iamcheyan/karabiner --yes  # inactive 276d, has content worth keeping
gh repo archive iamcheyan/leng --yes  # long dormant (5162d) but has content
gh repo archive iamcheyan/lmde7 --yes  # inactive 194d, has content worth keeping
gh repo archive iamcheyan/nano_cfg --yes  # inactive 275d, has content worth keeping
gh repo archive iamcheyan/openclaw-rescue-dashboard --yes  # inactive 187d, has content worth keeping
gh repo archive iamcheyan/panel_for_zhihu --yes  # long dormant (3514d) but has content
gh repo archive iamcheyan/pentadactylrc --yes  # long dormant (5159d) but has content
gh repo archive iamcheyan/private --yes  # private repo — inactive 194d
gh repo archive iamcheyan/rime_old --yes  # private old Rime config backup — superseded by rime/rime.xsb; archive, do not de
gh repo archive iamcheyan/rime_sbzrjp --yes  # inactive 232d, has content worth keeping
gh repo archive iamcheyan/sbzr --yes  # inactive 232d, has content worth keeping
gh repo archive iamcheyan/sbzr-chrome --yes  # inactive 281d, has content worth keeping
gh repo archive iamcheyan/sbzr.chrome.extension --yes  # inactive 216d, has content worth keeping
gh repo archive iamcheyan/sbzr_tools --yes  # inactive 234d, has content worth keeping
gh repo archive iamcheyan/simple_translation --yes  # long dormant (997d) but has content
gh repo archive iamcheyan/sublime-gbk --yes  # long dormant (5267d) but has content
gh repo archive iamcheyan/sway --yes  # inactive 229d, has content worth keeping
gh repo archive iamcheyan/titan2 --yes  # inactive 244d, has content worth keeping
gh repo archive iamcheyan/veikin.com --yes  # inactive 300d, has content worth keeping
gh repo archive iamcheyan/weather.openclaw.lcmd --yes  # inactive 180d, has content worth keeping
gh repo archive iamcheyan/workspace.openclaw.lcmd --yes  # private repo — inactive 192d
gh repo archive iamcheyan/xiaoshuo --yes  # private repo — inactive 355d
gh repo archive iamcheyan/zmk-config --yes  # inactive 290d, has content worth keeping
```

### 删除（高风险，不可逆 — 逐条确认后放开注释）

```bash
# gh repo delete iamcheyan/Alice --yes  # pure mirror of sofish/Alice (no own commits, behind)
# gh repo delete iamcheyan/Android16-Origin-Debian12-GUI --yes  # pure mirror of xlzhen-940218/Android16-Origin-Debian12-GUI (no own commits, behi
# gh repo delete iamcheyan/Humanizer-zh --yes  # pure mirror of op7418/Humanizer-zh (no own commits, identical)
# gh repo delete iamcheyan/MirForGodot --yes  # pure mirror of makeryangcom/MirForGodot (no own commits, identical)
# gh repo delete iamcheyan/Simplified-AZIK --yes  # pure mirror of yuru7/Simplified-AZIK (no own commits, identical)
# gh repo delete iamcheyan/Waybar --yes  # pure mirror of Alexays/Waybar (no own commits, behind)
# gh repo delete iamcheyan/agent --yes  # empty repository
# gh repo delete iamcheyan/azik-roman-table --yes  # pure mirror of toriwasa/azik-roman-table (no own commits, identical)
# gh repo delete iamcheyan/cc-switch-cli --yes  # pure mirror of SaladDay/cc-switch-cli (no own commits, behind)
# gh repo delete iamcheyan/con-terminal --yes  # pure mirror of nowledge-co/con-terminal (no own commits, behind)
# gh repo delete iamcheyan/css-auto-reload --yes  # pure mirror of allenm/css-auto-reload (no own commits, behind)
# gh repo delete iamcheyan/distro-grub-themes --yes  # pure mirror of AdisonCavani/distro-grub-themes (no own commits, behind)
# gh repo delete iamcheyan/down2nas --yes  # empty repository, never initialized
# gh repo delete iamcheyan/fcitx5-vinput --yes  # pure mirror of xifan2333/fcitx5-vinput (no own commits, behind)
# gh repo delete iamcheyan/folderify --yes  # pure mirror of lgarron/folderify (no own commits, behind)
# gh repo delete iamcheyan/fontconfig-zh-cn --yes  # pure mirror of ohmyarch/fontconfig-zh-cn (no own commits, identical)
# gh repo delete iamcheyan/fonts --yes  # pure mirror of owent-utils/font (no own commits, identical)
# gh repo delete iamcheyan/fudu --yes  # empty repository, never initialized
# gh repo delete iamcheyan/gentle-ai --yes  # pure mirror of Gentleman-Programming/gentle-ai (no own commits, behind)
# gh repo delete iamcheyan/hunk --yes  # pure mirror of modem-dev/hunk (no own commits, behind)
# gh repo delete iamcheyan/hyprquickframe --yes  # pure mirror of Ronin-CK/HyprQuickFrame (no own commits, identical)
# gh repo delete iamcheyan/jQuery-menu-aim --yes  # pure mirror of kamens/jQuery-menu-aim (no own commits, behind)
# gh repo delete iamcheyan/jquery-color --yes  # pure mirror of jquery/jquery-color (no own commits, behind)
# gh repo delete iamcheyan/just-talk --yes  # pure mirror of whoamihappyhacking/just-talk (no own commits, behind)
# gh repo delete iamcheyan/kissy --yes  # pure mirror of kissyteam/kissy (no own commits, behind)
# gh repo delete iamcheyan/mistermorph --yes  # pure mirror of quailyquaily/mistermorph (no own commits, behind)
# gh repo delete iamcheyan/noctalia --yes  # pure mirror of noctalia-dev/noctalia (no own commits, behind)
# gh repo delete iamcheyan/omarchy --yes  # pure mirror of basecamp/omarchy (no own commits, behind)
# gh repo delete iamcheyan/openWarp --yes  # pure mirror of zerx-lab/zap (no own commits, behind)
# gh repo delete iamcheyan/opencode-studio --yes  # pure mirror of Microck/opencode-studio (no own commits, behind)
# gh repo delete iamcheyan/opencode2api --yes  # pure mirror of TiaraBasori/OpenCode2API (no own commits, behind)
# gh repo delete iamcheyan/paopao-ce --yes  # pure mirror of rocboss/paopao-ce (no own commits, behind)
# gh repo delete iamcheyan/pi4aws --yes  # empty repository
# gh repo delete iamcheyan/rime-double-pinyin --yes  # pure mirror of rime/rime-double-pinyin (no own commits, behind)
# gh repo delete iamcheyan/tidy-sddm --yes  # pure mirror of loadfred/tidy-sddm (no own commits, identical)
# gh repo delete iamcheyan/tolaria --yes  # pure mirror of refactoringhq/tolaria (no own commits, behind)
# gh repo delete iamcheyan/vim-private --yes  # pure mirror of e7h4n/vim-private (no own commits, behind)
# gh repo delete iamcheyan/wechat-selkies --yes  # pure mirror of nickrunning/wechat-selkies (no own commits, behind)
# gh repo delete iamcheyan/zircon-legend-laucher --yes  # pure mirror of raphaelcheung/zircon-legend-laucher (no own commits, identical)
```

### fork 同步（可选，对保留的 fork）

```bash
# fork ChordVoxMini: behind upstream 7 — gh repo sync iamcheyan/ChordVoxMini
# fork VocoType-linux: behind upstream 191 — gh repo sync iamcheyan/VocoType-linux
# fork labwc-plus: behind upstream 28 — gh repo sync iamcheyan/labwc-plus
# fork mir2x: behind upstream 284 — gh repo sync iamcheyan/mir2x
# fork oc: behind upstream 372 — gh repo sync iamcheyan/oc
# fork pi: behind upstream 1104 — gh repo sync iamcheyan/pi
# fork pi-computer-use: behind upstream 56 — gh repo sync iamcheyan/pi-computer-use
# fork uniai: behind upstream 44 — gh repo sync iamcheyan/uniai
# fork zellij-cb: behind upstream 5 — gh repo sync iamcheyan/zellij-cb
```
