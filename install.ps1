<#
.SYNOPSIS
    Windows 一键安装/配置/卸载 C 语言开发环境 (MinGW + make + gdb + VSCode)
.DESCRIPTION
    自动安装 Chocolatey（若未安装），使用 Chocolatey 安装 mingw、make、gdb，
    配置 PowerShell 函数 ccdev，生成示例 C 项目，并可配置 VSCode 开发环境或卸载已装组件。
    需要以管理员身份运行。
.PARAMETER Auto
    自动模式，安装全部组件（编译器、构建工具、调试器、增强、示例），不包含 VSCode 配置。
.PARAMETER Compiler
    仅安装编译器 (MinGW)。
.PARAMETER Build
    仅安装构建工具 (make)。
.PARAMETER Debug
    仅安装调试器 (gdb)。
.PARAMETER Enhance
    仅配置 PowerShell 增强函数。
.PARAMETER Example
    仅生成示例 C 项目。
.PARAMETER VSCode
    仅配置 VSCode 开发环境（安装 VSCode 及 C/C++ 插件，生成配置文件）。
.PARAMETER Remove
    卸载已安装的 C 环境组件（MinGW、make、gdb），并移除相关的配置（环境变量、PowerShell 函数等）。
.PARAMETER Help
    显示帮助信息。
.EXAMPLE
    .\install.ps1 -Auto
    自动安装所有基础组件。
.EXAMPLE
    .\install.ps1 -Compiler -Debug
    只安装编译器和调试器。
.EXAMPLE
    .\install.ps1 -VSCode
    仅配置 VSCode 环境（需先安装基础组件）。
.EXAMPLE
    .\install.ps1 -Remove
    卸载所有已安装的 C 环境组件。
.NOTES
    作者: YourName
    版本: 1.3
    更新内容:
        - 增强 PATH 管理：添加条目前去重，备份 PATH 以便恢复
        - 组件安装前检测是否已存在，避免重复安装
        - 卸载时提供恢复环境变量的选项
        - 改进错误处理和网络检测
#>

param(
    [switch]$Auto,
    [switch]$Compiler,
    [switch]$Build,
    [switch]$Debug,
    [switch]$Enhance,
    [switch]$Example,
    [switch]$VSCode,
    [switch]$Remove,
    [switch]$Help
)

# 设置控制台输出编码为 UTF-8
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

# ---------- 初始化 ----------
$script:LogFile = "$PSScriptRoot\install.log"
$script:BackupDir = "$PSScriptRoot\backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$script:EnvBackupFile = "$script:BackupDir\env_backup.ps1"

function Write-Log {
    param([string]$Message)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time - $Message" | Tee-Object -FilePath $script:LogFile -Append
}

function Write-WarningLog {
    param([string]$Message)
    Write-Log "WARNING: $Message"
    Write-Warning $Message
}

function Throw-Error {
    param([string]$Message)
    Write-Log "ERROR: $Message"
    throw $Message
}

# ---------- 网络检测与重试 ----------
function Test-Network {
    $testHosts = @("google.com", "github.com", "chocolatey.org")
    foreach ($hostName in $testHosts) {
        if (Test-Connection -ComputerName $hostName -Count 1 -Quiet) {
            return $true
        }
    }
    return $false
}

function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [string]$ErrorMessage = "操作失败",
        [int]$Retries = 3
    )
    $attempt = 0
    while ($attempt -lt $Retries) {
        $attempt++
        try {
            & $ScriptBlock
            return
        } catch {
            Write-WarningLog "尝试 $attempt/$Retries 失败: $_"
            if ($attempt -eq $Retries) {
                Throw-Error "$ErrorMessage"
            }
            Start-Sleep -Seconds 2
        }
    }
}

# ---------- PATH 管理（用户级别，去重） ----------
function Get-UserPath {
    return [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Set-UserPath {
    param([string]$NewPath)
    [System.Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
    # 同时更新当前会话 PATH
    $env:Path = ([System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + $NewPath)
}

function Add-PathUser {
    param([string]$PathToAdd)
    if (-not (Test-Path $PathToAdd -PathType Container)) {
        Write-WarningLog "路径 $PathToAdd 不存在，跳过添加到 PATH"
        return
    }
    $currentPath = Get-UserPath
    $paths = $currentPath -split ';' | Where-Object { $_ -ne '' }
    if ($paths -contains $PathToAdd) {
        Write-Log "路径 $PathToAdd 已在用户 PATH 中"
        return
    }
    # 备份当前 PATH
    Backup-EnvVars
    $newPath = if ($currentPath) { $currentPath + ";" + $PathToAdd } else { $PathToAdd }
    Set-UserPath $newPath
    Write-Log "已将 $PathToAdd 添加到用户 PATH"
}

function Remove-PathUser {
    param([string]$PathToRemove)
    $currentPath = Get-UserPath
    $paths = $currentPath -split ';' | Where-Object { $_ -ne '' }
    if ($paths -notcontains $PathToRemove) {
        Write-Log "路径 $PathToRemove 不在用户 PATH 中，无需移除"
        return
    }
    $newPaths = $paths | Where-Object { $_ -ne $PathToRemove }
    $newPath = $newPaths -join ';'
    Set-UserPath $newPath
    Write-Log "已将 $PathToRemove 从用户 PATH 移除"
}

# ---------- 环境变量备份与恢复 ----------
function Backup-EnvVars {
    if (-not (Test-Path $script:BackupDir)) {
        New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
    }
    $userPath = Get-UserPath
    @"
# 环境变量备份 - $(Get-Date)
`$env:UserPathBefore = "$userPath"
"@ | Set-Content -Path $script:EnvBackupFile
    Write-Log "用户 PATH 已备份到 $script:EnvBackupFile"
}

function Restore-EnvVars {
    if (Test-Path $script:EnvBackupFile) {
        . $script:EnvBackupFile  # 点执行，加载备份的变量
        if ($env:UserPathBefore) {
            Set-UserPath $env:UserPathBefore
            Write-Log "已从备份恢复用户 PATH"
        }
    } else {
        Write-WarningLog "未找到环境变量备份，无法恢复"
    }
}

# ---------- 刷新当前会话 PATH ----------
function Update-SessionPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
    Write-Log "已刷新当前会话的 PATH 环境变量"
}

# ---------- 备份文件 ----------
function Backup-File {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        if (-not (Test-Path $script:BackupDir)) {
            New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
        }
        $dest = Join-Path $script:BackupDir (Split-Path $FilePath -Leaf)
        Copy-Item -Path $FilePath -Destination $dest -Force
        Write-Log "已备份 $FilePath 到 $dest"
    }
}

# ---------- 权限检查 ----------
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "错误: 此脚本需要管理员权限。请以管理员身份运行 PowerShell。" -ForegroundColor Red
    exit 1
}

# ---------- 网络检查 ----------
if (-not (Test-Network)) {
    Write-Warning "网络连接似乎有问题，安装过程可能失败。建议检查网络后重试。"
    $continue = Read-Host "是否仍要继续？(y/N)"
    if ($continue -notmatch '^[Yy]') {
        exit
    }
}

# ---------- 帮助信息 ----------
if ($Help) {
    @"
用法: .\install.ps1 [选项]
选项:
  -Auto         自动模式，安装全部基础组件（不包含 VSCode 配置）
  -Compiler     仅安装编译器
  -Build        仅安装构建工具
  -Debug        仅安装调试器
  -Enhance      仅配置增强
  -Example      仅生成示例项目
  -VSCode       仅配置 VSCode 开发环境
  -Remove       卸载所有已安装的 C 环境组件
  -Help         显示此帮助信息
"@
    exit 0
}

# ---------- Chocolatey 安装 ----------
function Install-Chocolatey {
    if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
        Write-Log "Chocolatey 未安装，正在安装..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-WithRetry -ScriptBlock {
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        } -ErrorMessage "Chocolatey 安装失败"
        refreshenv
        Update-SessionPath
        Write-Log "Chocolatey 安装完成"
    } else {
        Write-Log "Chocolatey 已安装"
    }
}

# ---------- 组件安装（带检测） ----------
function Install-Compiler {
    if (Get-Command gcc -ErrorAction SilentlyContinue) {
        $version = & gcc --version | Select-Object -First 1
        Write-Log "检测到已安装编译器: $version，跳过安装"
        return
    }
    Write-Log "安装 MinGW (gcc, g++, make)..."
    Invoke-WithRetry -ScriptBlock {
        choco install mingw -y
    } -ErrorMessage "MinGW 安装失败"
    if ($LASTEXITCODE -ne 0) { Throw-Error "MinGW 安装失败" }
    Update-SessionPath
    # 将 MinGW bin 目录添加到 PATH（Chocolatey 通常会自动添加，但确保一下）
    $mingwBin = "C:\ProgramData\mingw64\mingw64\bin"
    if (Test-Path $mingwBin) {
        Add-PathUser $mingwBin
    }
    Write-Log "编译器安装完成"
}

function Install-BuildTools {
    if (Get-Command make -ErrorAction SilentlyContinue) {
        $version = & make --version | Select-Object -First 1
        Write-Log "检测到已安装 make: $version，跳过安装"
        return
    }
    Write-Log "安装 make..."
    Invoke-WithRetry -ScriptBlock {
        choco install make -y
    } -ErrorMessage "make 安装失败"
    if ($LASTEXITCODE -ne 0) { Throw-Error "make 安装失败" }
    Update-SessionPath
    Write-Log "make 安装完成"
}

function Install-Debugger {
    if (Get-Command gdb -ErrorAction SilentlyContinue) {
        $version = & gdb --version | Select-Object -First 1
        Write-Log "检测到已安装 gdb: $version，跳过安装"
        return
    }

    $possiblePaths = @(
        "C:\ProgramData\mingw64\mingw64\bin\gdb.exe",
        "C:\ProgramData\mingw64\mingw32\bin\gdb.exe",
        "C:\Program Files\mingw64\bin\gdb.exe",
        "C:\mingw64\bin\gdb.exe"
    )
    $foundGdb = $false
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $gdbDir = Split-Path $path -Parent
            Write-Log "在 $gdbDir 找到 gdb，正在将其添加到用户 PATH..."
            Add-PathUser $gdbDir
            $foundGdb = $true
            break
        }
    }

    if (-not $foundGdb) {
        Write-WarningLog "未找到已安装的 gdb，尝试通过 Chocolatey 安装..."
        Invoke-WithRetry -ScriptBlock {
            choco install gdb -y
        } -ErrorMessage "Chocolatey 安装 gdb 失败" -Retries 1  # 只试一次，因为可能包不存在
        if ($LASTEXITCODE -ne 0) {
            Write-WarningLog "Chocolatey 安装 gdb 失败，请手动安装 gdb 或使用其他调试器。"
            return
        }
        Update-SessionPath
    }

    if (Get-Command gdb -ErrorAction SilentlyContinue) {
        Write-Log "gdb 安装/配置成功"
    } else {
        Write-WarningLog "gdb 仍未就绪，调试功能可能不可用。"
    }
}

# ---------- 验证安装 ----------
function Test-Installation {
    $tools = @("gcc", "make", "gdb")
    $allOk = $true
    foreach ($tool in $tools) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            $version = & $tool --version | Select-Object -First 1
            Write-Log "$tool 安装成功: $version"
        } else {
            Write-Log "警告: $tool 未找到"
            $allOk = $false
        }
    }
    return $allOk
}

# ---------- 配置 PowerShell 增强 ----------
function Setup-Enhancements {
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    # 备份原 profile
    Backup-File $profilePath
    $functionDef = @'
function ccdev {
    param([string]$source)
    if (-not $source) { Write-Host "用法: ccdev <源文件> [输出名]"; return }
    $output = if ($args[0]) { $args[0] } else { [System.IO.Path]::GetFileNameWithoutExtension($source) }
    gcc -Wall -Wextra -O2 -g $source -o $output
    if ($LASTEXITCODE -eq 0) { Write-Host "编译成功: $output" }
}
'@
    $currentContent = if (Test-Path $profilePath) { Get-Content $profilePath -Raw } else { "" }
    if ($currentContent -notmatch 'function ccdev\s*{') {
        Add-Content -Path $profilePath -Value "`n$functionDef`n"
        Write-Log "已添加函数 ccdev 到 PowerShell profile: $profilePath"
    } else {
        Write-Log "函数 ccdev 已存在于 profile 中"
    }
}

# ---------- 生成示例项目 ----------
function Generate-ExampleProject {
    $projectDir = "hello-c"
    if (Test-Path $projectDir) {
        $i = 1
        while (Test-Path "hello-c-$i") { $i++ }
        $projectDir = "hello-c-$i"
    }
    New-Item -ItemType Directory -Path "$projectDir\src" -Force | Out-Null

    # main.c
    @"
#include <stdio.h>

int main() {
    printf("Hello, C World!\n");
    return 0;
}
"@ | Set-Content -Path "$projectDir\src\main.c"

    # Makefile
    @"
CC = gcc
CFLAGS = -Wall -Wextra -O2 -g
TARGET = hello
SRCDIR = src
BUILDDIR = build

SOURCES = \$(wildcard \$(SRCDIR)/*.c)
OBJECTS = \$(patsubst \$(SRCDIR)/%.c,\$(BUILDDIR)/%.o,\$(SOURCES))

all: \$(TARGET)

\$(TARGET): \$(OBJECTS)
	\$(CC) \$^ -o \$@

\$(BUILDDIR)/%.o: \$(SRCDIR)/%.c | \$(BUILDDIR)
	\$(CC) \$(CFLAGS) -c \$< -o \$@

\$(BUILDDIR):
	mkdir -p \$@

clean:
	rm -f \$(BUILDDIR)/*.o \$(TARGET)

.PHONY: all clean
"@ | Set-Content -Path "$projectDir\Makefile"

    # README.md
    @"
# Hello C 示例项目

这是一个简单的 C 项目示例，包含一个源文件和一个 Makefile。

## 编译

运行 `make` 编译项目，生成可执行文件 `hello.exe`。

## 运行

`./hello`

## 调试

使用 `gdb hello` 进行调试。
"@ | Set-Content -Path "$projectDir\README.md"

    Write-Log "示例项目已生成在目录: $projectDir"
    Write-Log "进入目录并运行 'make' 编译"
}

# ---------- 配置 VSCode 环境 ----------
function Setup-VSCode {
    # 检查 VSCode 是否已安装
    $codePath = Get-Command code -ErrorAction SilentlyContinue
    if (-not $codePath) {
        Write-Log "Visual Studio Code 未安装，正在通过 Chocolatey 安装..."
        Invoke-WithRetry -ScriptBlock {
            choco install vscode -y
        } -ErrorMessage "VSCode 安装失败"
        if ($LASTEXITCODE -ne 0) {
            Throw-Error "VSCode 安装失败"
        }
        Update-SessionPath
        $codePath = Get-Command code -ErrorAction SilentlyContinue
        if (-not $codePath) {
            Throw-Error "VSCode 安装后仍无法找到 'code' 命令，请尝试重新打开终端。"
        }
    } else {
        Write-Log "Visual Studio Code 已安装"
    }

    # 安装 C/C++ 扩展
    Write-Log "正在安装 C/C++ 扩展..."
    $extResult = code --install-extension ms-vscode.cpptools --force
    if ($LASTEXITCODE -ne 0) {
        Write-WarningLog "C/C++ 扩展安装失败，请手动安装。"
    } else {
        Write-Log "C/C++ 扩展安装成功"
    }

    # 在当前目录（或示例项目目录）创建 .vscode 配置
    $targetDir = if (Test-Path "hello-c") { "hello-c" } else { "." }
    $vscodeDir = "$targetDir\.vscode"
    if (-not (Test-Path $vscodeDir)) {
        New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
    }

    # tasks.json (编译任务)
    $tasksJson = @'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "build hello",
            "type": "shell",
            "command": "make",
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "problemMatcher": ["$gcc"],
            "detail": "编译当前项目 (使用 Makefile)"
        }
    ]
}
'@
    Set-Content -Path "$vscodeDir\tasks.json" -Value $tasksJson

    # launch.json (调试配置)
    $launchJson = @'
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "(gdb) 启动",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/hello.exe",
            "args": [],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "miDebuggerPath": "gdb.exe",
            "setupCommands": [
                {
                    "description": "为 gdb 启用整齐打印",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ],
            "preLaunchTask": "build hello"
        }
    ]
}
'@
    Set-Content -Path "$vscodeDir\launch.json" -Value $launchJson

    Write-Log "VSCode 配置已生成在 $vscodeDir"
    Write-Log "你现在可以用 VSCode 打开 $targetDir 目录，按 Ctrl+Shift+B 编译，按 F5 调试。"
}

# ---------- 删除 C 环境 ----------
function Remove-CEnv {
    Write-Host "即将卸载以下组件：MinGW (gcc/g++/make)、make、gdb，并移除 PowerShell 函数 ccdev。" -ForegroundColor Yellow
    Write-Host "注意：此操作会删除通过 Chocolatey 安装的包，但不会删除手动添加的 PATH 条目（如有）。" -ForegroundColor Yellow
    $confirm = Read-Host "确定要继续吗？(y/N)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Log "用户取消卸载"
        return
    }

    # 备份 profile 和环境变量
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (Test-Path $profilePath) {
        Backup-File $profilePath
    }
    Backup-EnvVars

    # 卸载 Chocolatey 包
    $packages = @("mingw", "make", "gdb")
    foreach ($pkg in $packages) {
        if (choco list --local-only --exact $pkg | Select-String $pkg) {
            Write-Log "正在卸载 $pkg ..."
            choco uninstall $pkg -y
            if ($LASTEXITCODE -ne 0) {
                Write-WarningLog "$pkg 卸载可能不完整，请检查 Chocolatey 日志。"
            } else {
                Write-Log "$pkg 卸载成功"
            }
        } else {
            Write-Log "$pkg 未安装，跳过"
        }
    }

    # 从 PowerShell profile 中移除 ccdev 函数
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw
        if ($content -match '(?ms)^function ccdev\s*\{.*?\n\}') {
            $newContent = $content -replace '(?ms)^function ccdev\s*\{.*?\n\}', ''
            Set-Content -Path $profilePath -Value $newContent
            Write-Log "已从 PowerShell profile 中移除 ccdev 函数"
        } else {
            Write-Log "PowerShell profile 中未找到 ccdev 函数"
        }
    }

    # 提示用户是否要恢复 PATH 备份
    $restorePath = Read-Host "是否要恢复之前的 PATH 环境变量？(y/N)"
    if ($restorePath -match '^[Yy]') {
        Restore-EnvVars
    }

    Write-Log "卸载完成。建议重启 PowerShell 以确保环境变量更新。"
    Write-Host "卸载完成。建议重启 PowerShell。" -ForegroundColor Green
}

# ---------- 交互菜单 ----------
function Show-Menu {
    do {
        Clear-Host
        Write-Host "================================="
        Write-Host "  Windows C 语言开发环境一键安装"
        Write-Host "================================="
        Write-Host "1) 安装编译器 (MinGW)"
        Write-Host "2) 安装构建工具 (make)"
        Write-Host "3) 安装调试器 (gdb)"
        Write-Host "4) 配置开发增强 (PowerShell 函数 ccdev)"
        Write-Host "5) 生成示例 C 项目"
        Write-Host "6) 一键全部安装 (基础组件)"
        Write-Host "7) 配置 VSCode 环境"
        Write-Host "8) 删除 C 环境"
        Write-Host "0) 退出"
        $choice = Read-Host "请选择 [0-8]"
        switch ($choice) {
            "1" { Install-Compiler; Test-Installation }
            "2" { Install-BuildTools }
            "3" { Install-Debugger }
            "4" { Setup-Enhancements }
            "5" { Generate-ExampleProject }
            "6" { 
                Install-Compiler
                Install-BuildTools
                Install-Debugger
                Setup-Enhancements
                Generate-ExampleProject
                break
            }
            "7" { Setup-VSCode }
            "8" { Remove-CEnv }
            "0" { exit }
            default { Write-Host "无效选择"; Start-Sleep 1 }
        }
        if ($choice -ne "6" -and $choice -ne "7" -and $choice -ne "8") {
            Write-Host "`n按 Enter 键继续..."
            [void](Read-Host)
        }
    } while ($choice -ne "6" -and $choice -ne "7" -and $choice -ne "8")
}

# ---------- 主逻辑 ----------
function Main {
    Write-Log "========== 开始执行 =========="

    # 如果选择了 Remove 参数，直接执行卸载并退出
    if ($Remove) {
        Remove-CEnv
        Write-Log "========== 卸载完成 =========="
        return
    }

    # 否则正常流程需要 Chocolatey
    Install-Chocolatey

    # 根据参数执行
    if ($Compiler -or $Build -or $Debug -or $Enhance -or $Example -or $VSCode) {
        if ($Compiler) { Install-Compiler }
        if ($Build)    { Install-BuildTools }
        if ($Debug)    { Install-Debugger }
        if ($Enhance)  { Setup-Enhancements }
        if ($Example)  { Generate-ExampleProject }
        if ($VSCode)   { Setup-VSCode }
    } elseif ($Auto) {
        Install-Compiler
        Install-BuildTools
        Install-Debugger
        Setup-Enhancements
        Generate-ExampleProject
    } else {
        Show-Menu
    }

    Write-Log "========== 执行完成 =========="
    Write-Host "脚本执行完成。详细信息请查看 install.log" -ForegroundColor Green
}

# 调用主函数
Main