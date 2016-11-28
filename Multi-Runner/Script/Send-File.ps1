<#

.作者
  黄涛

.站点
  https://github.com/htve/GitlabCIForDotNet

.概要

将文件发送到远程会话。

.例子

PS > .\Send-File sourceFile targetFile remoteIP remoteUserName remotePassword

.说明

#如果ci服务器与目标服务器不在同一个域中,需要执行以下两条命令

#开启Powershell远程管理(ci和目标都要执行)
Enable-PsRemoting

#配置受信任的主机(只在ci执行)
Set-Item WSMan:\localhost\client\trustedhosts -value 192.168.3.20

#>

param(
    ## 本地计算机上的路径
    [Parameter(Mandatory = $true)]
    [string]$Source,

    ## 远程计算机上的目标路径
    [Parameter(Mandatory = $true)]
    [string]$Destination,
    
	## 远程服务器IP 可以是多个ip,但用户名密码与目标目录必须相同.例如192.168.1.1,192.168.1.2
	[Parameter(Mandatory = $true)]
    [array]$RemoteIPList,
	
	## 远程服务器登录名
	[Parameter(Mandatory = $true)]
    [string]$RemoteUserName,
	
	## 远程服务器登录名
	[Parameter(Mandatory = $true)]
    [string]$RemotePassword
)

Set-StrictMode -Version 3

## 创建目录
if(Test-Path $REMOTE_PACKAGES_PATH\$CI_PROJECT_NAME){} else {md $REMOTE_PACKAGES_PATH\$CI_PROJECT_NAME -ErrorAction Stop}

## 输入用户凭据
$defaultCredential = New-Object Management.Automation.PSCredential $RemoteUserName, (ConvertTo-SecureString $RemotePassword -AsPlainText -Force) -ErrorAction Stop

## 新建远程会话
$session = New-PSSession -ComputerName $RemoteIPList -Credential $defaultCredential -ErrorAction Stop

$remoteScript = {
    param($destination, $bytes)

    ## 将目标路径转换为完整的文件系统路径（以支持相对路径）
    $Destination = $executionContext.SessionState.`
        Path.GetUnresolvedProviderPathFromPSPath($Destination)

    ## 将内容写入新文件
    $file = [IO.File]::Open($Destination, "OpenOrCreate")
    $null = $file.Seek(0, "End")
    $null = $file.Write($bytes, 0, $bytes.Length)
    $file.Close()
}

## 获取源文件，然后开始读取其内容
$sourceFile = Get-Item $source

## 删除先前存在的文件（如果存在）
Invoke-Command -Session $session {
    if(Test-Path $args[0]) { Remove-Item $args[0] }
} -ArgumentList $Destination

## 现在把它分成块
Write-Progress -Activity "Sending $Source" -Status "Preparing file"

$streamSize = 1MB
$position = 0
$rawBytes = New-Object byte[] $streamSize
$file = [IO.File]::OpenRead($sourceFile.FullName)

while(($read = $file.Read($rawBytes, 0, $streamSize)) -gt 0)
{
    Write-Progress -Activity "Writing $Destination" `
        -Status "Sending file" `
        -PercentComplete ($position / $sourceFile.Length * 100)

    ## 确保我们的数组与我们从磁盘读取的数据大小相同
    if($read -ne $rawBytes.Length)
    {
        [Array]::Resize( [ref] $rawBytes, $read)
    }

    ## 并将该阵列发送到远程系统
    Invoke-Command -Session $session $remoteScript `
        -ArgumentList $destination,$rawBytes

    ## 确保我们的数组与我们从磁盘读取的数据大小相同
    if($rawBytes.Length -ne $streamSize)
    {
        [Array]::Resize( [ref] $rawBytes, $streamSize)
    }
    
    [GC]::Collect()
    $position += $read
}

$file.Close()

## 显示结果
Invoke-Command -Session $session { Get-Item $args[0] } -ArgumentList $Destination