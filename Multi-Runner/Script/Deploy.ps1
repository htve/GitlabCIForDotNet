<#

.作者
  黄涛

.站点
  https://github.com/htve/GitlabCIForDotNet

.概要

执行远程操作,部署web

.例子

PS > .\Deploy.ps1 IP SiteName

.说明

#>
param(
	## 远程服务器IP
	[Parameter(Mandatory = $true)]
    [string]$IP,
	
	## 远程web名称
	[Parameter(Mandatory = $true)]
    [string]$SiteName
)

Set-StrictMode -Version 3

Try
{
	## 服务器列表
	$session = ."$SERVER_PATH" $IP

	$deploy = {
		param(
		## 要加压的文件路径
		[Parameter(Mandatory = $true)]
		[string]$File,
		
		## 远程web名称
		[Parameter(Mandatory = $true)]
		[string]$SiteName
		)

		Stop-Website $SiteName -ErrorAction Stop
		Stop-WebAppPool $SiteName -ErrorAction Stop
		$IIS_Path="IIS:\Sites\"+$SiteName
		$WEB_PATH = Get-WebFilePath $IIS_Path
		$WEB_PATH = "-o"+$WEB_PATH
		."$env:ProgramFiles\7-Zip\7z.exe" x $File $WEB_PATH -y
		Start-Website $SiteName -ErrorAction Stop
		Start-WebAppPool $SiteName -ErrorAction Stop
	}
	Invoke-Command -Session $session.Session $deploy -ArgumentList ($session.Path+"\$CI_BUILD_REF.7z"),$SiteName
}
catch  
{  
    throw "An unknown exception error occurred."
	exit
}  