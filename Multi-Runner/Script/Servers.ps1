<#

.作者
  黄涛

.站点
  https://github.com/htve/GitlabCIForDotNet

.概要

远程服务器的登录信息

.例子

PS > $servers = .\Send-File

.说明

#>

param(
	## 远程服务器IP
	[Parameter(Mandatory = $true)]
    [string]$IP
)

Set-StrictMode -Version 3

Try
{
	$servers = @{
		'192.168.3.20'=@{
			UserName='a\Administrator';
			Password='5!@~g^m@KBCn,5,L';
			Path = 'C:\Packages\'+$CI_PROJECT_NAME;
		};
		'192.168.3.21'=@{
			UserName='a\Administrator';
			Password='5!@~g^m@KBCn,5,L';
			Path = 'C:\Packages\'+$CI_PROJECT_NAME;
		};
		'192.168.3.22'=@{
			UserName='a\Administrator';
			Password='5!@~g^m@KBCn,5,L';
			Path = 'C:\Packages\'+$CI_PROJECT_NAME;
		};
	};

	if($servers.ContainsKey($IP))
	  {
		## 输入用户凭据
		$defaultCredential = New-Object Management.Automation.PSCredential $servers[$IP].UserName, (ConvertTo-SecureString $servers[$IP].Password -AsPlainText -Force) -ErrorAction Stop
		## 新建远程会话
		return @{ Path= $servers[$IP].Path;Session = (New-PSSession -ComputerName $IP -Credential $defaultCredential -ErrorAction Stop) }
	  }
	  else
	  {
		throw "IP Session "+$n+" does not exist."
		exit
	  }
}
catch  
{  
    throw "An unknown exception error occurred."
	exit
}  