# 贡献指南

感谢你对 C-Bootstrap 项目的兴趣！我们欢迎任何形式的贡献，包括报告问题、提交功能请求、改进文档或提交代码。

## 报告问题

如果你在使用脚本时遇到问题，请先检查以下内容：

- 是否以管理员身份运行 PowerShell？
- 网络是否正常，能否访问 GitHub 或 Gitee？
- 查看 `install.log` 中的错误信息。

如果问题仍然存在，请 [新建一个 Issue](https://github.com/ISHAOHAO/C-Bootstrap/issues/new)，并提供以下信息：

- 操作系统版本（`winver` 命令输出）
- PowerShell 版本（`$PSVersionTable.PSVersion`）
- 你执行的完整命令
- 完整的错误输出
- `install.log` 文件内容（或相关部分）

## 提交 Pull Request

1. Fork 本仓库并克隆到本地。
2. 创建新的分支：`git checkout -b my-feature`。
3. 进行修改，确保代码风格与现有代码一致。
4. 如果添加了新功能，请更新 README 中的相关部分。
5. 提交前请测试你的修改（建议在 Windows 10/11 的 PowerShell 5.1 和 PowerShell 7 中测试）。
6. 推送分支并创建 Pull Request，描述你的改动。

## 代码规范

- 使用动词-名词形式的函数名（例如 `Install-Compiler`）。
- 为每个函数添加注释，说明其用途、参数和返回值。
- 变量名使用驼峰式，常量使用全大写。
- 遵循 PowerShell 的 [最佳实践](https://docs.microsoft.com/en-us/powershell/scripting/developer/windows-powershell)。

## 开发环境

- Windows 10/11（或 Windows Server 2016+）
- PowerShell 5.1 或 PowerShell 7
- 管理员权限（用于测试安装和卸载）

## 许可证

通过贡献代码，你同意将你的贡献置于项目的 MIT 许可证下。

再次感谢你的支持！