## 
## Gitlab CI for .Net
##
## 作者:黄涛
## 站点:https://github.com/htve/GitlabCIForDotNet

function GetServers()
{
    $servers = @{
		'192.168.3.20'=@{
			UserName='a\Administrator';
			Password='5!@~g^m@KBCn,5,L';
			Path = 'C:\Packages\'+$global:ProjectName;
		};
		'192.168.3.21'=@{
			UserName='a\Administrator';
			Password='5!@~g^m@KBCn,5,L';
			Path = 'C:\Packages\'+$global:ProjectName;
		};
		'192.168.3.80'=@{
			UserName='a\Administrator';
			Password='6*mDqFWE6An)3}ED';
			Path = 'D:\Packages\'+$global:ProjectName;
		};
	};
    return $servers
}

function GetServerSession([string]$IP)
{
    Try
    {
        $servers=GetServers
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
		    exit 1
	    }
    }
    catch  
    {  
        throw $_.Exception
        exit 1
    }  
}

function GetMsBuildPath([switch] $Use32BitMsBuild)
{
    ## 获取MsBuild.exe的最新版本的路径。如果找不到MsBuild.exe，则抛出异常。
	$registryPathToMsBuildToolsVersions = 'HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\'
	if ($Use32BitMsBuild)
	{
		## 如果32位路径存在则使用它，否则将使用与当前系统位一致的路径。
		$registryPathTo32BitMsBuildToolsVersions = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\MSBuild\ToolsVersions\'
		if (Test-Path -Path $registryPathTo32BitMsBuildToolsVersions)
		{
			$registryPathToMsBuildToolsVersions = $registryPathTo32BitMsBuildToolsVersions
		}
	}

	## 获取MsBuild最新版本所在目录的路径。
	$msBuildToolsVersionsStrings = Get-ChildItem -Path $registryPathToMsBuildToolsVersions | Where-Object { $_ -match '[0-9]+\.[0-9]' } | Select-Object -ExpandProperty PsChildName
	$msBuildToolsVersions = @{}
	$msBuildToolsVersionsStrings | ForEach-Object {$msBuildToolsVersions.Add($_ -as [double], $_)}
	$largestMsBuildToolsVersion = ($msBuildToolsVersions.GetEnumerator() | Sort-Object -Descending -Property Name | Select-Object -First 1).Value
	$registryPathToMsBuildToolsLatestVersion = Join-Path -Path $registryPathToMsBuildToolsVersions -ChildPath ("{0:n1}" -f $largestMsBuildToolsVersion)
	$msBuildToolsVersionsKeyToUse = Get-Item -Path $registryPathToMsBuildToolsLatestVersion
	$msBuildDirectoryPath = $msBuildToolsVersionsKeyToUse | Get-ItemProperty -Name 'MSBuildToolsPath' | Select -ExpandProperty 'MSBuildToolsPath'

	if(!$msBuildDirectoryPath)
	{
		throw 'The registry on this system does not appear to contain the path to the MsBuild.exe directory.'
	}

	## 获取MsBuild可执行文件的路径。
	$msBuildPath = (Join-Path -Path $msBuildDirectoryPath -ChildPath 'msbuild.exe')

	if(!(Test-Path $msBuildPath -PathType Leaf))
	{
		throw "MsBuild.exe was not found on this system at the path specified in the registry, '$msBuildPath'."
	}

	return $msBuildPath
}

function GetVisualStudioToolsVersion
{
    ## vs版本列表
    $vsCommandPromptPaths = @(
        @{Path=$env:VS140COMNTOOLS + 'VsDevCmd.bat';Version="14.0";}
        @{Path=$env:VS120COMNTOOLS + 'VsDevCmd.bat';Version="12.0";}
        @{Path=$env:VS110COMNTOOLS + 'VsDevCmd.bat';Version="11.0";}
        @{Path=$env:VS100COMNTOOLS + 'vcvarsall.bat';Version="10.0";}
    )

	$vsToolsVersion = $null
	foreach ($path in $vsCommandPromptPaths)
	{
		try
		{
			if (Test-Path -Path $path.Path)
			{
				$vsToolsVersion ="/ToolsVersion:"+ $path.Version
				break
			}
		}
		catch 
        { 
            throw $_.Exception
            exit 1
        }
	}
    ## 返回 MsBuild ToolsVersion 参数
	return $vsToolsVersion
}

function RestoreNugetPackages()
{
    $slnFile = Get-ChildItem -Include *.sln -recurse | Select-Object -First 1
    if(!$slnFIle) { throw "Did not find the .sln file"; exit 1}
    Write-Host "Sln Path: $slnFile `n"

    $nugetPath=$global:FilePath+"\NuGet\nuget.exe"
    if(!(Test-Path $nugetPath -PathType Leaf)) { throw "Path $nugetPath does not exist"; exit 1 }

    Write-Host "Start Restoring Nuget Packages ...`n"
    Write-Host .$nugetPath restore $slnFile `n
    $result = .$nugetPath restore $slnFile
    Write-Host "Restore Nuget Packages To Completed`n"
    return $slnFile
}

function InvokeMsBuild(
    [Parameter(Position=0,Mandatory = $true,ValueFromPipeline=$true,HelpMessage="The path to the file to build with MsBuild (e.g. a .sln or .csproj file).")]
    [Alias("Path")]
    [string]$ProjectPath,

    [parameter(Mandatory=$false)]
    [string]$OutDir,

    [parameter(Mandatory=$false)]
    [string]$WebProjectOutputDir,

    [parameter(Mandatory=$false)]
    [switch] $Use32BitMsBuild,

    [parameter(Mandatory=$false)]
    [switch] $UseDebug
    )
{   
    $build= GetMsBuildPath -Use32BitMsBuild:$Use32BitMsBuild
    Write-Host "MsBuild Path: $build`n"

    $toolsVersion=GetVisualStudioToolsVersion

    $configuration="Release"
    if($UseDebug){$configuration="Debug"}

    if(-not [String]::IsNullOrEmpty($OutDir)){ $OutDir="/p:OutDir="+ $OutDir }

    if(-not [String]::IsNullOrEmpty($WebProjectOutputDir)){ $WebProjectOutputDir="/p:WebProjectOutputDir="+ $WebProjectOutputDir }

    Write-Host "Start Build ...`n"
    Write-Host $build $projectPath $toolsVersion /p:RunCodeAnalysis=false /consoleloggerparameters:ErrorsOnly /p:Configuration=$configuration /nologo /verbosity:quiet /maxcpucount $OutDir $WebProjectOutputDir `n
    .$build $projectPath $toolsVersion /p:RunCodeAnalysis=false /consoleloggerparameters:ErrorsOnly /p:Configuration=$configuration /nologo /verbosity:quiet /maxcpucount $OutDir $WebProjectOutputDir
    Write-Host "Build To Completed`n"
    return
}

function InvokeMsBuildSln (
    [parameter(Mandatory=$false)]
    [string]$OutDir,

    [parameter(Mandatory=$false)]
    [string]$WebProjectOutputDir,

    [parameter(Mandatory=$false)]
    [switch] $Use32BitMsBuild,

    [parameter(Mandatory=$false)]
    [switch] $UseDebug
    )
{   
    Try
    {
        $projectPath = RestoreNugetPackages
        InvokeMsBuild -Path $projectPath -OutDir $OutDir -WebProjectOutputDir $WebProjectOutputDir -Use32BitMsBuild:$Use32BitMsBuild -UseDebug:$UseDebug
    }
    catch  
    {  
        throw $_.Exception
	    exit 1
    }  
}

function InvokeMsBuildCsporj (
    [parameter(Mandatory=$true)]
    [array]$TestProjectsName,

    [parameter(Mandatory=$false)]
    [switch] $Use32BitMsBuild,

    [parameter(Mandatory=$false)]
    [switch] $UseDebug
    )
{
    Try
    {
        $projectPath = RestoreNugetPackages

        $testFiles = @()
        foreach ($p in $TestProjectsName -Split ",") {$testFiles+=$p+".csproj"}

        $test_projects = Get-ChildItem -Include $testFiles -recurse

        foreach ($p in $test_projects) 
        {
            $fileName="$global:CiProjectPath/BuildTests/"+$p.BaseName
            InvokeMsBuild -Path $p -OutDir $fileName -Use32BitMsBuild:$Use32BitMsBuild -UseDebug:$UseDebug
        }
    }
    catch  
    {  
        throw $_.Exception
	    exit 1
    }  
}

function TestDlls (
    [parameter(Mandatory=$true)]
    [array]$TestProjectsName
    )
{
    Try
    {
        $testFiles = @()
        $paths=$TestProjectsName -Split ","
        foreach ($p in $paths) {$testFiles+=Get-ChildItem -Include "$p.dll" -recurse}
        if(!$testFiles){ throw "Did not find the need to test the files `n"; exit 1}
        Write-Host "The files to be tested are: `n"
        [string]::Join("`n", $testFiles)

        Write-Host "Start Tests ...`n"
        $test = ."$global:FilePath\\dotCover\\dotCover.exe" analyse /TargetExecutable="$global:FilePath\\xUnitRunner\\xunit.console.exe" /TargetArguments="$testFiles" /Output="Coverage.json" /ReportType="JSON" /Filters="$global:CoverFilters"
		Write-Output $test
		if($test[-5].Contains("Analysed application exited with code")){ exit 1 }
        Write-Host "Tests To Completed`n"

        $CoveragePercent = (Get-Content Coverage.json -TotalCount 6)[-1]
        Write-Host $CoveragePercent
        return
    }
    catch  
    {  
        throw $_.Exception
	    exit 1
    }  
}

function BuildUnpack ()
{
    Try
    {
        InvokeMsBuildSln "$global:CiProjectPath/Deploy/bin" "$global:CiProjectPath/Deploy"

        Write-Host "Start Unpack ...`n"
        cd .\Deploy\
        if (-not (test-path "$env:ProgramFiles\7-Zip\7z.exe")) {throw "$env:ProgramFiles\7-Zip\7z.exe needed"; exit 1} 
        set-alias sz "$env:ProgramFiles\7-Zip\7z.exe" 
        $7z = sz a -t7z -mx=1 "..\$global:CommitId.7z"
        Write-Host "Unpack To Completed`n"
    }
    catch  
    {  
        throw $_.Exception
	    exit 1
    }  
}

function UploadFile ([array]$RemoteIPList)
{
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
		    $session = GetServerSession $n
            Enable-PsRemoting
            Set-Item WSMan:\localhost\client\trustedhosts -value $n -Force
		    Write-Host "Start Uploading To $n ...`n"
		    $result = Invoke-Command $send -ArgumentList "$global:CommitId.7z",$session.Path,$session.Session
            Write-Host "Uploaded To $n`n"
	    }
    }
    catch  
    {  
        throw $_.Exception
	    exit 1
    }  
}

function Deploy ([string]$IP,[string]$SiteName)
{
    Try
    {
	    ## 服务器列表
	    $session = GetServerSession $IP

	    $deploy = {
		    param(
		    ## 要解压的文件路径
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
        
        Write-Host "Start Deploy To $IP ...`n"
	    $result = Invoke-Command -Session $session.Session $deploy -ArgumentList ($session.Path+"\$global:CommitId.7z"),$SiteName
        Write-Host "Deployed To $IP`n"
    }
    catch  
    {  
        throw $_.Exception
	    exit 1
    }  
}

Export-ModuleMember -Function InvokeMsBuildSln
Export-ModuleMember -Function InvokeMsBuildCsporj
Export-ModuleMember -Function TestDlls
Export-ModuleMember -Function BuildUnpack
Export-ModuleMember -Function UploadFile
Export-ModuleMember -Function Deploy