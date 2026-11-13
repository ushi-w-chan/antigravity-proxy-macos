# Antigravity macOS 代理配置

把整个目录复制到另一台 Mac。先安装 Python 3 并启动本机 HTTP 代理。配置 CLI 时需要已安装 `agy`。配置桌面版时需要把官方 Antigravity 安装到 `/Applications/Antigravity.app`，且系统的 `open` 支持 `--env`（用 `open --help` 检查）。

如果要配置桌面版，先用 ⌘Q 完全退出 Antigravity。在项目目录按需执行：

```sh
./setup.zsh                              # 配置两项
./setup.zsh install cli                  # 只配置 agy
./setup.zsh install app                  # 只配置桌面版
./setup.zsh install app http://127.0.0.1:10809
# 为两项使用自定义端口
./setup.zsh install http://127.0.0.1:10809
```

脚本会为 zsh 添加仅对 `agy` 进程生效的代理配置。新开终端运行 `agy` 即可。桌面版原始应用移到 `/Applications/.antigravity-original/Antigravity.app`，安装目录需要当前账户可写。脚本在 `~/Applications` 创建同名、同图标的代理启动器，并固定到 Dock。Spotlight 可能需要一点时间刷新。原版运行时，Dock 仍可能另显示一个运行中的图标。

用 Dock 或 Spotlight 打开 **Antigravity**，再试一次登录和模型请求。修改代理端口时，退出应用后用新地址重新执行安装命令。

## 恢复

退出 Antigravity，然后执行：

```sh
./setup.zsh uninstall                    # 恢复两项
./setup.zsh uninstall cli                # 只移除 agy 配置
./setup.zsh uninstall app                # 只恢复桌面版
```

原版应用会移回 `/Applications`，Dock 入口会指回原版，脚本管理的 zsh 配置会被移除。安装脚本会拒绝覆盖同名的其他应用（包括之前手工创建且没有本项目标识的启动器）。

## 桌面版更新

隐藏目录下的应用内自动更新未实测。使用官网安装包手动升级时，安装包可能把新版放到 `/Applications/Antigravity.app`，此时启动器仍会打开隐藏目录里的版本。退出应用后，将隐藏目录中的旧版移到其他位置，再重新运行安装脚本，以隐藏新版并更新入口。
