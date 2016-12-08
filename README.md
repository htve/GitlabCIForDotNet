## GitlabCIForDotNet简介
Gitlab CI For .Net Web的CI脚本 . 原则上适用于任何.Net开发 , 但可能需要更改其中的部分脚本

##关于
  前一段时间空闲 , 觉得Gitlab+Jenkins的CI太麻烦了 , 主要是因为要使用两种软件 , 太繁琐了. 所以萌生了使用Gitlab Runner的想法. 经过几天的不懈努力 , 加之各种Google , 翻看各种文档 , 终于弄出了一个集自动构建 , 自动测试 , 自动上传 , 自动发布 , 且支持回滚的CI脚本 . 脚本经过本人的测试 , 暂时没有发现大的Bug , 特分享出来 . 如果你在使用过程中发现了Bug , 请及时联系我 !
  By: 黄涛<htve$outlook.com>

##前期准备
1. 首先需要下载[Gitlab CI Runner](https://gitlab-ci-multi-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-ci-multi-runner-windows-amd64.exe)到`C:\Multi-Runner` , 并将其改名为**gitlab-ci-multi-runner.exe**
2. 下载[JetBrains dotCover Command line tools](https://www.jetbrains.com/dotcover/download/#section=commandline "JetBrains dotCover Command line tools")并解压到`C:\Multi-Runner\dotCover`  
3. 配置.gitlab-ci.yml中的变量 
3. 配置部署服务器信息 , 参见 Script\Servers.ps1 
4. 如果部署多个Runner , 必须部署在同一个服务器上 , 并且取消注释 第40行(GIT_STRATEGY: none) 同时注释第47和54行 . 注册多个Runner命令 :  
`sc create 服务名称 binPath= "Runner路径 run --working-directory 多个Runner的工作目录必须相同 --config Runner配置文件 --service gitlab-runner --syslog"`  
  Demo :  
`sc create Gitlab_Runner2 binPath= "C:\Multi-Runner2\gitlab-ci-multi-runner.exe run --working-directory C:\Gitlab_Working --config C:\Multi-Runner2\config.toml --service gitlab-runner --syslog"`  

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
4. 在Powershell中执行以下命令(仅单Runner , 多个Runner请执行sc命令) , 并启动相应的服务  
    **gitlab-ci-multi-runner install**  
    **gitlab-ci-multi-runner start**
5. 将项目中的.gitlab-ci.yml根据自身情况修改后添加到gitlab的.gitlab-ci.yml中

##后期配置
1. 在**项目管理**->**CI/CD设置**中,修改**测试覆盖率分析**正则表达式为 `block0 = \[\["Total",(.*?),`
2. 在**README.md**中引入**构建徽章**与**覆盖率徽章**