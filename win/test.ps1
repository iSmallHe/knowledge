# 注释一下
# Set-ExecutionPolicy:Restricted（受限）、AllSigned（所有脚本必须有签名）、RemoteSigned（本地脚本不受签名限制，远程脚本必须有签名）或Bypass（不受限制）
$text = "haha";
$up = $text.Substring(0, 1).ToUpper() + $text.Substring(1);
Write-Output $up;

# 类型
$int = 1; # 整数
$float = 1.0; # 浮点数
$bool = $true; # 布尔值
$string = "hello world"; # 字符串
$char = 'a'; # 字符
$null = $null; # 空值
$object = New-Object -TypeName PSObject -Property @{ Name = "zhangsan"; Age = 18; }; # 对象
$array = @(1, 2, 3, 4, 5); # 数组
$hashtable = @{ Name = "zhangsan"; Age = 18; }; # 哈希表
$datetime = Get-Date; # 日期时间
$regex = [regex]::new("^[a-zA-Z0-9]+$"); # 正则表达式
$xml = [xml]@"
<root>
    <name>zhangsan</name>
    <age>18</age>
</root>
"@; # XML
$xml = [xml]$xml; # XML对象
$xml.root.name; # 访问XML对象属性
$xml.root.age; # 访问XML对象属性
$xml.root.name = "lisi"; # 修改XML对象属性

# 操作符
$num = 1;
Write-Host $num -eq 1; # 等于
Write-Host $num -ne 1; # 不等于
Write-Host $num -lt 1; # 小于
Write-Host $num -le 1; # 小于等于
Write-Host $num -gt 1; # 大于
Write-Host $num -ge 1; # 大于等于
Write-Host $num -like "1"; # 模糊匹配
Write-Host $num -notlike "1"; # 不模糊匹配
Write-Host $num -match "1"; # 正则匹配
Write-Host $num -notmatch "1"; # 不正则匹配
Write-Host $num -in 1, 2, 3; # 在集合中
Write-Host $num -notin 1, 2, 3; # 不在集合中
Write-Host $num -is [int]; # 是类型
Write-Host $num -isnot [int]; # 不是类型
Write-Host $num -and $num -eq 1; # 与
Write-Host $num -or $num -eq 1; # 或
Write-Host $num -xor $num -eq 1; # 异或
Write-Host $num -not $num -eq 1; # 非
Write-Host $num -band 1; # 按位与
Write-Host $num -bor 1; # 按位或
Write-Host $num -bxor 1; # 按位异或
Write-Host $num -shl 1; # 左移
Write-Host $num -shr 1; # 右移
Write-Host $num -as [int]; # 转换类型
Write-Host $num -join ","; # 数组连接
Write-Host $num -split ","; # 数组分割
Write-Host $num -replace "1", "2"; # 替换
Write-Host $num -creplace "1", "2"; # 大小写不敏感替换
Write-Host $num -cireplace "1", "2"; # 大小写敏感替换

# 运算符
Write-Host 1 + 2; # 加
Write-Host 1 - 2; # 减
Write-Host 1 * 2; # 乘
Write-Host 1 / 2; # 除
Write-Host 1 % 2; # 取余
Write-Host 1 ** 2; # 幂运算
Write-Host 1 ++; # 自增
Write-Host 1 --; # 自减
Write-Host 1 += 2; # 加等于
Write-Host 1 -= 2; # 减等于
Write-Host 1 *= 2; # 乘等于
Write-Host 1 /= 2; # 除等于
Write-Host 1 %= 2; # 取余等于
Write-Host 1 **= 2; # 幂等于
Write-Host 1 ++= 2; # 自增等于
Write-Host 1 --= 2; # 自减等于

# math
Math::Round(1.5);

# 数组
$array = (1, 2, 3, 4, 5);
foreach ($currItem in $array) {
    <# $currItem is the current item #>
    Write-Output $currItem;
}

# 哈希表
$hashTable = @{
    "name" = "zhangsan";
    "age"  = 18;
}
$hashTable["name"] = "lisi";
Write-Output $hashTable["name"];

#while
$i = 0;
while ($i -lt 10) {
    Write-Output $i;
    $i++;
}
#do-while
$i = 0;
do {
    Write-Output $i;
    $i++;
} while ($i -lt 10);
#for
for ($i = 0; $i -lt 10; $i++) {
    Write-Output $i;
}

# try-catch-finally
try {
    $a = 1 / 0;
}
catch {
    Write-Output "catch: $_";
}
finally {
    Write-Output "finally";
}

# log
Write-Host "hello world" -ForegroundColor Green -BackgroundColor Red;
Write-Debug "hello world"; # 调试信息
Write-Error "hello world"; # 错误信息

# 写入到文件
Write-Host "hello world" | Out-File -Append myLog.log;

# 函数
function Add-Numbers {
    param (
        [int]$a,
        [int]$b
    )
    return $a + $b;
}
Write-Output (Add-Numbers 1 2);
Write-Output (Add-Numbers -a 1 -b 2);


# 文件
$path = "C:\Users\zhangsan\Desktop\test.txt";
$exists = Test-Path $path;
if ($exists) {
    Write-Output "文件存在";
}
else {
    Write-Output "文件不存在";
}

$temporaryFile = [System.IO.Path]::GetTempFileName();
$temporaryFile = [System.IO.Path]::GetTempPath() + "test.txt";
Get-Content $temporaryFile; # 读取文件内容
Set-Content $temporaryFile "hello world"; # 写入文件内容
Add-Content $temporaryFile "hello world"; # 追加文件内容
Remove-Item $temporaryFile; # 删除文件
Copy-Item $temporaryFile "C:\Users\zhangsan\Desktop\test.txt"; # 复制文件
Move-Item $temporaryFile "C:\Users\zhangsan\Desktop\test.txt"; # 移动文件
Rename-Item $temporaryFile "test.txt"; # 重命名文件

# 创建文件/文件夹
New-Item -Path "C:\Path\To\Your\Folder" -ItemType Directory
New-Item -Path "C:\Path\To\Your\File.txt" -ItemType File

#json
$json = '{"name":"zhangsan","age":18}';
$person = $json | ConvertFrom-Json;
Write-Output $person.name; # 访问属性
Write-Output $person.age; # 访问属性
Write-Output $person | ConvertTo-Json; # 转换为json字符串

#http
$uri = "https://api.github.com/users/octocat";
$response = Invoke-RestMethod -Uri $uri -Method Get;
$body = @{
    account  = "test";
    password = "test"
};
$response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json";
Write-Debug $response.StatusCode; # 调试信息
Write-Debug $response.Content; # 调试信息

#启动程序
Start-Process -FilePath "notepad.exe" -ArgumentList "C:\Users\zhangsan\Desktop\test.txt"; # 启动程序
$jarPath = "C:\Users\zhangsan\Desktop\test.jar";
Start-Process -FilePath "java" -ArgumentList "-jar" $jarPath; # 启动java程序
Start-Process -FilePath "java" -ArgumentList "-jar" $jarPath -NoNewWindow; # 启动java程序不新建窗口
Start-Process -FilePath "java" -ArgumentList "-jar" $jarPath -NoNewWindow -Wait; # 启动java程序不新建窗口并等待结束
Start-Process java -ArgumentList "-jar " + $jarPath + " --server.port=8080 --config=config.yml" -WindowStyle Hidden; # 启动java程序不新建窗口
Start-Process java -ArgumentList "-jar C:\path\to\your-application.jar --server.port=8080 --config=config.yml" -NoNewWindow -PassThru; # 启动java程序不新建窗口并返回进程对象
Start-Process java -ArgumentList "-jar C:\path\to\your-application.jar --server.port=8080 --config=config.yml" -NoNewWindow -PassThru | Select-Object -Property Name, Id; # 启动java程序不新建窗口并返回进程对象

# NSSM
nssm install MyJavaApp "C:\Program Files\Java\jdk-17\bin\java.exe" "-jar C:\path\to\your-application.jar --server.port=8080 --config=config.yml" # 安装服务
nssm start MyJavaApp # 启动服务
Start-Service MyJavaApp # 启动服务
nssm stop MyJavaApp # 停止服务
Stop-Service MyJavaApp # 停止服务
nssm remove MyJavaApp # 删除服务
Remove-Service MyJavaApp # 删除服务

Get-Service MyJavaApp # 获取服务状态
Get-Service MyJavaApp | Select-Object -Property Name, Status # 获取服务状态

#杀掉进程
Get-Process | Where-Object { $_.Name -eq "java" } | Stop-Process -Force # 杀掉进程
Get-Process | Where-Object { $_.Name -eq "java" } | Stop-Process -Force -PassThru # 杀掉进程并返回进程对象
Get-Process | Where-Object { $_.Name -eq "java" } | Stop-Process -Force -PassThru | Select-Object -Property Name, Id # 杀掉进程并返回进程对象
Get-Process | Where-Object { $_.Name -eq "java" } | Stop-Process -Force -PassThru | Select-Object -Property Name, Id | Format-Table # 杀掉进程并返回进程对象以表格形式显示
Stop-Process -Id $pid -Force # 杀掉当前进程
Get-Process -Id $pid # 获取当前进程对象
Get-Process -Id $pid | Stop-Process -Force # 杀掉当前进程并返回进程对象

#执行其他脚本文件
$scriptPath = "C:\Users\zhangsan\Desktop\test.ps1";
. $scriptPath # 执行脚本文件
$scriptPath = "C:\Users\zhangsan\Desktop\test.bat";
Start-Process -FilePath $scriptPath # 执行bat文件
$scriptPath = "C:\Users\zhangsan\Desktop\test.cmd";
Start-Process -FilePath $scriptPath # 执行cmd文件

#获取进程详细信息
Get-CimInstance -ClassName Win32_Process | Where-Object { $_.Name -eq "java.exe" } | Select-Object -Property Name, ProcessId, CommandLine # 获取进程详细信息
Get-CimInstance -ClassName Win32_Process | Where-Object { $_.CommandLine -like "*nacos*" } | Select-Object -Property Name, ProcessId, CommandLine # 获取进程详细信息
#关闭进程
Get-CimInstance -ClassName Win32_Process | Where-Object { $_.CommandLine -like "*nacos*" } | Foreach-Object {
    Stop-Process -Id $_.ProcessId -Force # 杀掉进程
}

