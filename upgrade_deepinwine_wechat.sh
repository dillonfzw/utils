#! /usr/bin/env bash

# refer to:
# >> https://bbs.deepin.org/forum.php?mod=redirect&goto=findpost&ptid=181711&pid=612493
wget https://dldir1.qq.com/weixin/Windows/WeChatSetup.exe
env WINEPREFIX=~/.deepinwine/Deepin-WeChat deepin-wine WeChatSetup.exe
