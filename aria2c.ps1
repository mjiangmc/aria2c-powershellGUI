# https://github.com/mjiangmc
# 这是一个将aria2c可视化的脚本
# 你需要替换路径为你的aria2c存放位置然后在脚本末尾查看示例

function Convert-BytesToString { 
    param([double]$aria2c_bytes)
    if ($aria2c_bytes -ge 1GB) {
        return "{0:N2} GB" -f ($aria2c_bytes / 1GB)
    } elseif ($aria2c_bytes -ge 1MB) {
        return "{0:N2} MB" -f ($aria2c_bytes / 1MB)
    } elseif ($aria2c_bytes -ge 1KB) {
        return "{0:N2} KB" -f ($aria2c_bytes / 1KB)
    } else {
        return "$aria2c_bytes B"
    }
}

function 启动Aria2 {
    # 这里填你的aria2c路径
    $aria2c_aria2Path = "$env:APPDATA\aria2c\aria2c.exe"
    $aria2c_rpcPort = 6802
    Start-Process -FilePath $aria2c_aria2Path -ArgumentList "--enable-rpc", "--rpc-listen-all", "--rpc-listen-port=$aria2c_rpcPort" -WindowStyle Hidden
    Start-Sleep -Seconds 2
}

function 关闭Aria2 {
    $aria2c_rpcUrl = "http://localhost:6802/jsonrpc"
    $aria2c_shutdownPayload = @{
        jsonrpc = "2.0"
        id      = "shutdown"
        method  = "aria2.forceShutdown"
        params  = @()
    } | ConvertTo-Json -Depth 5

    Invoke-RestMethod -Uri $aria2c_rpcUrl -Method Post -Body $aria2c_shutdownPayload -ContentType "application/json" > $null
}

function Convert-BytesToString { 
    param([double]$aria2c_bytes)
    if ($aria2c_bytes -ge 1GB) {
        return "{0:N2} GB" -f ($aria2c_bytes / 1GB)
    } elseif ($aria2c_bytes -ge 1MB) {
        return "{0:N2} MB" -f ($aria2c_bytes / 1MB)
    } elseif ($aria2c_bytes -ge 1KB) {
        return "{0:N2} KB" -f ($aria2c_bytes / 1KB)
    } else {
        return "$aria2c_bytes B"
    }
}

function 下载文件 {
    param(
        [Parameter(Mandatory = $true)][string]$aria2c_url,
        [Parameter(Mandatory = $true)][string]$aria2c_savePath,
        [Parameter(Mandatory = $true)][string]$aria2c_name
    )

    if ((Test-Path $aria2c_savePath) -and (Get-Item $aria2c_savePath).PSIsContainer) {
        $fileName = [System.IO.Path]::GetFileName($aria2c_url.Split('?')[0])
        $aria2c_savePath = Join-Path $aria2c_savePath $fileName
    }

    if (Test-Path $aria2c_savePath) {
        Remove-Item $aria2c_savePath -Force
        Write-Host "已删除存在的文件：$aria2c_savePath"
    }

    $aria2c_rpcUrl = "http://localhost:6802/jsonrpc"
    $aria2c_uris = [string[]]@($aria2c_url)
    $aria2c_options = @{
    out = [System.IO.Path]::GetFileName($aria2c_savePath)
    dir = [System.IO.Path]::GetDirectoryName($aria2c_savePath)
    }


    $aria2c_addPayload = @{
        jsonrpc = "2.0"
        id      = "start"
        method  = "aria2.addUri"
        params  = @($aria2c_uris, $aria2c_options)
    } | ConvertTo-Json -Depth 5

    $aria2c_response = Invoke-RestMethod -Uri $aria2c_rpcUrl -Method Post -Body $aria2c_addPayload -ContentType "application/json"
    $aria2c_gid = $aria2c_response.result
    Write-Host "任务 GID：" $aria2c_gid
    Write-Host "资源名称：" $aria2c_name
    Write-Host "保存路径：" $aria2c_savePath

    while ($true) {
        Start-Sleep -Milliseconds 500
        try {
            $aria2c_statusPayload = @{
                jsonrpc = "2.0"
                id      = "status"
                method  = "aria2.tellStatus"
                params  = @([string]$aria2c_gid, @("completedLength", "totalLength", "downloadSpeed", "status"))
            } | ConvertTo-Json -Depth 5

            $aria2c_statusResponse = Invoke-RestMethod -Uri $aria2c_rpcUrl -Method Post -Body $aria2c_statusPayload -ContentType "application/json"
            $aria2c_result = $aria2c_statusResponse.result

            $aria2c_completed = [double]$aria2c_result.completedLength
            $aria2c_total     = [double]$aria2c_result.totalLength
            $aria2c_speed     = [double]$aria2c_result.downloadSpeed

            $aria2c_percent = if ($aria2c_total -gt 0) { [math]::Round(($aria2c_completed / $aria2c_total) * 100, 2) } else { 0 }
            $aria2c_etaSeconds = if ($aria2c_speed -gt 0) { ($aria2c_total - $aria2c_completed) / $aria2c_speed } else { 0 }
            $aria2c_etaFormatted = [TimeSpan]::FromSeconds($aria2c_etaSeconds).ToString("hh\:mm\:ss")

            $aria2c_completedStr = Convert-BytesToString $aria2c_completed
            $aria2c_totalStr     = Convert-BytesToString $aria2c_total
            $aria2c_speedStr     = Convert-BytesToString $aria2c_speed

            $aria2c_statusText = "已下载 $aria2c_percent%, 速度: $aria2c_speedStr/s, 已下载: $aria2c_completedStr / $aria2c_totalStr, 剩余时间: $aria2c_etaFormatted"
            Write-Progress -Activity "下载中 $aria2c_name" -Status $aria2c_statusText -PercentComplete $aria2c_percent

            if ($aria2c_result.status -eq "complete") { break }
        } catch {
            Write-Host "获取状态失败：$($_.Exception.Message)"
            break
        }
    }

    Write-Progress -Activity "下载中" -Status "下载完成" -Completed
    Write-Host "下载完成！"
}



启动Aria2

# 注意:如果进度条不动可能是因为没有权限读取哪个目录换个目录或以管理员运行powershell在执行脚本
下载文件 "https://demo.cn/1.zip" "D:/" "压缩包文件"

下载文件 "https://demo.cn/2.zip" "D:/" "压缩包文件"

关闭Aria2

