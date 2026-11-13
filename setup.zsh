#!/bin/zsh
set -euo pipefail

action=${1:-install}
component=all
case "${2:-}" in
  cli|app|all) component=$2; shift ;;
esac
proxy=${2:-http://127.0.0.1:7890}
agy_binary=''
original=/Applications/Antigravity.app
hidden=/Applications/.antigravity-original/Antigravity.app
launcher="$HOME/Applications/Antigravity.app"
zshrc="${ZDOTDIR:-$HOME}/.zshrc"
launcher_id=local.antigravity.proxy-launcher
fail() { print -u2 -- "$*"; exit 1; }

[[ "$action" == install || "$action" == uninstall ]] || fail "用法：$0 [install [cli|app|all] [代理地址] | uninstall [cli|app|all]]"
[[ "$OSTYPE" == darwin* ]] || fail '此脚本需要 macOS。'
command -v python3 >/dev/null || fail '请先安装 Python 3。'
if [[ "$action" == install ]]; then
  [[ "$proxy" =~ '^http://127\.0\.0\.1:[0-9]{1,5}$' ]] || fail '请输入本机 HTTP 代理地址，例如 http://127.0.0.1:7890。'
  port=${proxy##*:}
  (( 10#$port > 0 && 10#$port <= 65535 )) || fail '代理端口无效。'
  /usr/bin/nc -z -G 2 127.0.0.1 "$port" || fail "本机代理端口 $port 未开放。"
  if [[ "$component" != app ]]; then
    agy_binary=$(whence -p agy || true)
    [[ -n "$agy_binary" ]] || agy_binary="$HOME/.local/bin/agy"
    [[ -x "$agy_binary" ]] || fail '请先安装 agy CLI。'
  fi
fi

if [[ "$component" != cli ]]; then
  if [[ -e "$launcher" ]]; then
    existing_id=$(plutil -extract CFBundleIdentifier raw "$launcher/Contents/Info.plist" 2>/dev/null || true)
    [[ "$existing_id" == "$launcher_id" ]] || fail "已有其他应用占用 $launcher"
  fi
  if pgrep -f '^/Applications/(\.antigravity-original/)?Antigravity\.app/Contents/MacOS/' >/dev/null; then
    fail '请先用 ⌘Q 退出 Antigravity，再运行脚本。'
  fi
  [[ ! -e "$original" || ! -e "$hidden" ]] || fail '检测到两份原版 Antigravity，请先处理重复安装。'

fi

if [[ "$component" != cli && "$action" == install ]]; then
  source_app=$original
  [[ ! -d "$hidden" ]] || source_app=$hidden
  [[ -d "$source_app" ]] || fail "请先把 Antigravity 安装到 $original"
  icon=$(plutil -extract CFBundleIconFile raw "$source_app/Contents/Info.plist")
  [[ "$icon" == *.icns ]] || icon="$icon.icns"
  [[ -f "$source_app/Contents/Resources/$icon" ]] || fail '找不到原版图标。'

  mkdir -p "${launcher:h}"
  stage=$(mktemp -d "${launcher:h}/.antigravity-setup.XXXXXX")
  trap 'rm -rf -- "$stage"' EXIT
  /usr/bin/osacompile -o "$stage/Antigravity.app" <<APPLESCRIPT
on run
  set proxyURL to "$proxy"
  set bypassList to "127.0.0.1,localhost,::1"
  set launchCommand to "/usr/bin/open -a /Applications/.antigravity-original/Antigravity.app"
  repeat with variableName in {"HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy"}
    set launchCommand to launchCommand & " --env " & quoted form of ((contents of variableName) & "=" & proxyURL)
  end repeat
  repeat with variableName in {"NO_PROXY", "no_proxy"}
    set launchCommand to launchCommand & " --env " & quoted form of ((contents of variableName) & "=" & bypassList)
  end repeat
  do shell script launchCommand
end run
APPLESCRIPT
  bundle="$stage/Antigravity.app"
  plist="$bundle/Contents/Info.plist"
  cp "$source_app/Contents/Resources/$icon" "$bundle/Contents/Resources/icon.icns"
  plutil -remove CFBundleIconName "$plist" 2>/dev/null || true
  plutil -replace CFBundleIconFile -string icon.icns "$plist"
  plutil -replace CFBundleIdentifier -string "$launcher_id" "$plist"
  codesign --force --sign - "$bundle"
  codesign --verify "$bundle"

  if [[ "$source_app" == "$original" ]]; then
    mkdir -p "${hidden:h}"
    mv "$original" "$hidden"
  fi
  if [[ -e "$launcher" ]]; then
    mv "$launcher" "$stage/previous.app"
  fi
  if ! mv "$bundle" "$launcher"; then
    [[ ! -e "$stage/previous.app" ]] || mv "$stage/previous.app" "$launcher"
    [[ "$source_app" != "$original" ]] || mv "$hidden" "$original"
    fail '无法安装代理启动器。'
  fi
  register=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
  "$register" -f "$launcher"
  mdimport "$launcher" || true
elif [[ "$component" != cli ]]; then
  if [[ -d "$hidden" ]]; then
    mv "$hidden" "$original"
    rmdir "${hidden:h}" 2>/dev/null || true
  fi
  if [[ -d "$launcher" ]]; then
    rm -r -- "$launcher"
  fi
fi

python3 "${0:A:h}/configure.py" "$action" "$proxy" "$agy_binary" "$zshrc" "$launcher" "$original" "$component"
print -- '配置完成。'
