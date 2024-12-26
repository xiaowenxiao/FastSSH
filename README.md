# FastSSH

<img src="https://bucket.ryanfight.org/images/file-20241225170249607.png" width="400" alt="FastSSH">

FastSSH 是一个简单的脚本，用于通过 SSH 连接到多个服务器。它支持使用 SSH 密码进行身份验证，并提供了一个友好的用户界面来选择要连接的服务器。

## 特性

- 支持通过 SSH 密码连接
- 现代化并且友好的命令行界面
- 支持多种服务器类型（开发、测试、生产、其他）
- 自动编号和分组显示服务器列表

## 安装

1. 克隆或下载此仓库：

   ```bash
   git clone https://github.com/xiaowenxiao/FastSSH.git
   cd FastSSH
   ```

2. 确保您已安装 `expect`：

   - 对于 Ubuntu/Debian：
     ```bash
     sudo apt-get install expect
     ```
   - 对于 CentOS/RHEL：
     ```bash
     sudo yum install expect
     ```

3. 配置服务器信息：
   - 编辑 `.fastssh.conf` 文件，按照以下格式添加服务器信息：
     ```
     # 格式：名称|IP地址|端口|用户名|密码|备注
     dev|192.168.123.29|22|root|yourpassword|开发服务器
     ```

## 使用

1. 运行脚本：

   ```bash
   ./FastSSH.sh
   ```

2. 按照提示选择要连接的服务器编号，或输入 'q' 退出。

## 许可证

本项目采用 MIT 许可证，详情请参阅 [LICENSE](LICENSE) 文件。
