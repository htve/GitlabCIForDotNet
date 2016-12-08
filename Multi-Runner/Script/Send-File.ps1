<#

.作者
  黄涛

.站点
  https://github.com/htve/GitlabCIForDotNet

.概要

将文件发送到远程会话。

.例子

PS > .\Send-File sourceFile remoteIP

.说明

#如果ci服务器与目标服务器不在同一个域中,需要执行以下两条命令

#开启Powershell远程管理(ci和目标都要执行)
Enable-PsRemoting

#配置受信任的主机(只在ci服务器执行)
Set-Item WSMan:\localhost\client\trustedhosts -value 192.168.3.20

#配置Servers.ps1
#>

param(
    ## 本地计算机上的路径
    [Parameter(Mandatory = $true)]
    [string]$Source,
    
	## 远程服务器IP 可以是多个ip,例如192.168.1.1,192.168.1.2
	[Parameter(Mandatory = $true)]
    [array]$RemoteIPList
)

Set-StrictMode -Version 3
Try
{
	$send={
		param(
			## 本地计算机上的路径
			[Parameter(Mandatory = $true)]
			[string]$Source,
			
			## 远程计算机上的目标路径
			[Parameter(Mandatory = $true)]
			[string]$Destination,
			
			## session
			[Parameter(Mandatory = $true)]
			[System.Management.Automation.Runspaces.PSSession] $Session
		)
		
		Set-StrictMode -Version 3
		
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

		$Destination+=('\\'+(Get-Item $Source).Name)
		
		## 获取源文件，然后开始读取其内容
		$sourceFile = Get-Item $source

		Invoke-Command -Session $session {
			## 检测目标文件夹是否存在,不存在则创建
			if(!(Test-Path $args[0])){md $args[0] -ErrorAction Stop}
			## 删除先前存在的文件（如果存在）
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
	}

	foreach($n in $RemoteIPList)
	{
		$session = ."$SERVER_PATH" $n
		## 传送文件
		Invoke-Command $send -ArgumentList $Source,$session.Path,$session.Session
	}
}
catch  
{  
    throw "An unknown exception error occurred."
	exit
}  