<?php
// +----------------------------------------------------------------------
// | 奥贝通讯 · 设备数据上报与后台管理系统
// +----------------------------------------------------------------------
// | 【骨架文件】本文件在本公开仓库中仅保留类名 / 函数名与签名，
// | 完整的核心业务实现未包含在本仓库中。
// | 说明见仓库根目录 README.md 与 docs/CORE_FILES.md 。
// +----------------------------------------------------------------------

// 原文件：app/admin/common.php（213 行 / 8790 字节）
// 职责：后台公共函数：密码加盐、操作日志、字节格式化、代理删改保护等。
// 注意：密码盐值等真实配置请勿写入本仓库，部署时填入真实值。

// 部署时请把下面的占位符换成真实的密码盐值（切勿把真实盐值提交进仓库）
function password($password, $password_code='YOUR_PASSWORD_SALT')
{
    // 核心实现未包含在本仓库（详见 README 与 docs/CORE_FILES.md）
}

function addlog($operation_id='')
{
    // 核心实现未包含在本仓库（详见 README 与 docs/CORE_FILES.md）
}

function format_bytes($size, $delimiter = '')
{
    // 核心实现未包含在本仓库（详见 README 与 docs/CORE_FILES.md）
}

function agent_delete_guard()
{
    // 核心实现未包含在本仓库（详见 README 与 docs/CORE_FILES.md）
}

function agent_is_delete_action($controller, $action)
{
    // 核心实现未包含在本仓库（详见 README 与 docs/CORE_FILES.md）
}
