<?php
// +----------------------------------------------------------------------
// | 奥贝通讯 · 设备数据上报与后台管理系统
// +----------------------------------------------------------------------
// | 【骨架文件】本文件在本公开仓库中仅保留类名 / 函数名与签名，
// | 完整的核心业务实现未包含在本仓库中。
// | 说明见仓库根目录 README.md 与 docs/CORE_FILES.md 。
// +----------------------------------------------------------------------

// 原文件：app/admin/controller/Permissions.php（163 行 / 6039 字节）
// 职责：后台权限基类：登录校验、节点鉴权。

namespace app\admin\controller;

use \think\Cache;
use \think\Controller;
use think\Loader;
use think\Db;
use \think\Session;

class Permissions extends Controller
{
    protected function _initialize()
    {
        // 核心实现未包含在本仓库（详见 README 与 docs/CORE_FILES.md）
    }

    protected function onlyLoginCheck()
    {
        // 核心实现未包含在本仓库（详见 README 与 docs/CORE_FILES.md）
    }
}
