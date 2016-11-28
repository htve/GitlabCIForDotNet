## GitlabCIForDotNet简介
Gitlab CI For .Net Web的CI脚本 . 原则上适用于任何.Net开发 , 但可能需要更改其中的部分脚本

##关于
  前一段时间空闲 , 觉得Gitlab+Jenkins的CI太麻烦了 , 主要是因为要使用两种软件 , 太繁琐了. 所以萌生了使用Gitlab Runner的想法. 经过几天的不懈努力 , 加之各种Google , 翻看各种文档 , 终于弄出了一个集自动构建 , 自动测试 , 自动上传 , 自动发布 , 且支持回滚的CI脚本 . 脚本经过本人的测试 , 暂时没有发现大的Bug , 特分享出来 . 如果你在使用过程中发现了Bug , 请及时联系我 !
  By: 黄涛<htve$outlook.com>

##前期准备
1. 首先需要下载Gitlab CI  
   [https://gitlab-ci-multi-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-ci-multi-runner-windows-amd64.exe](https://gitlab-ci-multi-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-ci-multi-runner-windows-amd64.exe)
2. 将项目中的Multi-Runner下载到`c:\`
2. 将Gitlab CI 改名为 **gitlab-ci-multi-runner.exe** 并复制到 `C:\Multi-Runner`

##Windows Runner 安装
1. 将Multi-Runner.7z 解压缩到C:\Multi-Runner
2. 以管理员身份打开Powershell,执行以下命令
    PS C:\> cd **C:\Multi-Runner**  
    PS C:\Multi-Runner> **.\gitlab-ci-multi-runner register**  
    Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):  
    **http://192.168.3.22/ci**  
    Please enter the gitlab-ci token for this runner:  
    **jdW4Z3Yf8fxiq8fpbwBU**  
    Please enter the gitlab-ci description for this runner:  
    \[WIN-J05S2W1\]: **Default2**  
    Please enter the gitlab-ci tags for this runner (comma separated):  
    **dev**  
    Registering runner... succeeded runner=jdW4Z3Yf  
    Please enter the executor: docker, docker-ssh, virtualbox, docker+machine, kubernetes, parallels, shell, ssh, docker-ssh+machine:  
    **shell**  
    Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!  
    PS C:\Multi-Runner>  
3. 安装后不要关闭Powershell,将config.toml修改为:
    concurrent = 1  
    check_interval = 0  
    [[runners]]  
      name = "Default1"  
      url = "http://192.168.3.22/ci"  
      token = "8beefdf46801a51fe6e9c8428f0b90"  
      executor = "shell"  
      **shell = "powershell"**  
      [runners.cache]  
4. 在Powershell中执行以下命令  
    **gitlab-ci-multi-runner install**  
    **gitlab-ci-multi-runner start**
5. 将项目中的.gitlab-ci.yml根据自身情况修改后添加到gitlab的.gitlab-ci.yml中
