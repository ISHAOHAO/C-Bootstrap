# ⚙️ C-Bootstrap

一键搭建可用的 C 语言开发环境，告别繁琐的配置。  
支持 Windows 平台，自动安装 MinGW、make、gdb，配置 VSCode 开发环境，并提供一键卸载。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## ✨ 特性

- **智能检测**：自动识别 Windows 版本、管理员权限、网络连通性，检测已安装组件避免重复。
- **一键安装核心工具**：通过 Chocolatey 自动安装 MinGW（gcc/g++/make）、make 和 gdb，并配置 PATH 环境变量。
- **安全可靠**：修改任何配置文件前自动备份，支持一键回滚；PATH 管理去重，可恢复原始状态。
- **开发体验增强**：为 PowerShell 添加 `ccdev` 函数，快速编译 C 文件（自动添加常用编译参数 `-Wall -Wextra -O2 -g`）。
- **示例项目生成**：创建包含 `src/main.c`、`Makefile`、`README.md` 的 C 项目模板，用户可直接 `make` 编译。
- **VSCode 集成**：自动安装 Visual Studio Code 及 C/C++ 扩展，生成 `.vscode/tasks.json` 和 `.vscode/launch.json`，实现一键编译（`Ctrl+Shift+B`）和调试（`F5`）。
- **一键卸载与清理**：卸载所有通过脚本安装的组件，并可选恢复原始环境变量和 PowerShell 配置。
- **交互/静默双模式**：交互式菜单引导操作，也支持命令行参数实现静默安装或选择性安装特定组件。
- **详细日志**：所有操作记录到 `install.log`，便于排查问题。

---

## 📦 快速开始

### Windows（PowerShell）

> ⚠️ 必须以 **管理员身份** 运行 PowerShell

#### 方法一：一键远程运行

复制并粘贴以下命令到 PowerShell 中执行：

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/ISHAOHAO/C-Bootstrap/main/install.ps1'))
```

如果上述地址被屏蔽（如网络服务提供商/DNS 阻止），请尝试镜像：

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://gitee.com/is-haohao/C-Bootstrap/raw/main/install.ps1'))
```

#### 方法二：本地运行

1. 下载 `install.ps1` 脚本到本地（可从 [GitHub Release](https://github.com/ISHAOHAO/C-Bootstrap/releases) 获取）。
2. 以管理员身份打开 PowerShell，导航到脚本所在目录。
3. 执行：

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install.ps1
```

### 使用命令行直接安装（静默模式）

```powershell
.\install.ps1 -Auto
```

### 仅安装特定组件

```powershell
.\install.ps1 -Compiler -Debug          # 只安装编译器和调试器
.\install.ps1 -VSCode                    # 仅配置 VSCode 环境
.\install.ps1 -Example                    # 仅生成示例项目
```

### 卸载所有组件

```powershell
.\install.ps1 -Remove
```

---

## 🖥️ 支持的操作系统

| 分类     | 系统版本                          |
|----------|-----------------------------------|
| Windows  | Windows 7 / 8 / 10 / 11（PowerShell 5.1+） |

> 注：脚本需要管理员权限，并依赖 Chocolatey 包管理器（自动安装）。

---

## 📚 使用说明

### 交互式菜单

直接运行 `.\install.ps1`，将显示如下菜单：

```txt
=================================
  Windows C 语言开发环境一键安装
=================================
1) 安装编译器 (MinGW)
2) 安装构建工具 (make)
3) 安装调试器 (gdb)
4) 配置开发增强 (PowerShell 函数 ccdev)
5) 生成示例 C 项目
6) 一键全部安装 (基础组件)
7) 配置 VSCode 环境
8) 删除 C 环境
0) 退出
```

根据提示选择数字即可完成对应操作。

### 命令行参数

| 参数        | 说明                                                         |
| ----------- | ------------------------------------------------------------ |
| `-Auto`     | 自动模式，安装全部基础组件（编译器 + 构建工具 + 调试器 + 增强 + 示例项目），不包含 VSCode 配置 |
| `-Compiler` | 仅安装编译器（MinGW）                                        |
| `-Build`    | 仅安装构建工具（make）                                       |
| `-Debug`    | 仅安装调试器（gdb）                                          |
| `-Enhance`  | 仅配置 PowerShell 增强函数（`ccdev`）                        |
| `-Example`  | 仅生成示例 C 项目                                            |
| `-VSCode`   | 仅配置 VSCode 开发环境（需先安装基础组件）                   |
| `-Remove`   | 卸载所有已安装的 C 环境组件，并可选恢复环境变量              |
| `-Help`     | 显示帮助信息                                                 |

### 示例

```powershell
# 静默安装全部基础组件
.\install.ps1 -Auto

# 安装编译器和 VSCode 环境
.\install.ps1 -Compiler -VSCode

# 卸载环境，并在卸载后询问是否恢复 PATH
.\install.ps1 -Remove
```

---

## 🧩 脚本模块介绍

`install.ps1` 采用模块化设计，主要函数如下：

| 函数                    | 功能说明                                                     |
| ----------------------- | ------------------------------------------------------------ |
| `Install-Chocolatey`    | 检查并安装 Chocolatey 包管理器，支持网络重试。               |
| `Install-Compiler`      | 安装 MinGW（gcc/g++/make），并自动将 bin 目录添加到用户 PATH。 |
| `Install-BuildTools`    | 安装 make 工具（若 MinGW 未包含）。                          |
| `Install-Debugger`      | 安装 gdb，优先使用 MinGW 自带的版本，否则通过 Chocolatey 安装。 |
| `Test-Installation`     | 验证 gcc、make、gdb 是否可用，并输出版本信息。               |
| `Setup-Enhancements`    | 在 PowerShell profile 中添加 `ccdev` 函数，便于快速编译。    |
| `Generate-ExampleProject` | 生成示例 C 项目目录，包含源代码、Makefile 和说明文档。       |
| `Setup-VSCode`          | 安装 VSCode 及 C/C++ 扩展，生成调试和任务配置文件。          |
| `Remove-CEnv`           | 卸载所有组件，从 profile 中移除函数，并可选择恢复环境变量。  |
| `Add-PathUser` / `Remove-PathUser` | 安全地添加/移除用户 PATH 条目（自动去重、备份）。            |
| `Backup-EnvVars` / `Restore-EnvVars` | 备份和恢复用户环境变量，用于回滚。                      |
| `Invoke-WithRetry`      | 带重试机制的脚本块执行，提高网络操作成功率。                 |
| `Show-Menu`             | 交互式菜单主循环。                                           |

---

## 🔧 开发与贡献

欢迎提交 Issue 或 Pull Request！

### 报告问题

如果你在使用中遇到任何问题，请在 [Issues](https://github.com/ISHAOHAO/C-Bootstrap/issues) 页面提交，并提供：

- Windows 版本
- PowerShell 版本（`$PSVersionTable.PSVersion`）
- 执行的命令和错误日志（位于脚本同目录下的 `install.log`）

### 贡献代码

1. Fork 本仓库。
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)。
3. 提交你的改动 (`git commit -m 'Add some AmazingFeature'`)。
4. 推送到分支 (`git push origin feature/AmazingFeature`)。
5. 打开一个 Pull Request。

请确保代码符合 [PowerShell 最佳实践](https://docs.microsoft.com/en-us/powershell/scripting/developer/windows-powershell)，并添加适当的注释。

### 开发环境设置

- 克隆仓库到本地。
- 以管理员身份打开 PowerShell，导航到项目目录。
- 修改脚本并测试（建议在虚拟机或测试环境中进行）。

详细的贡献指南请参阅 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

## 📄 许可证

[MIT](LICENSE) © 2026 C-Bootstrap contributors
