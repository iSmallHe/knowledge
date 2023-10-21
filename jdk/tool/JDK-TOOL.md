# jdk常用的工具

## java

Java虚拟机（JVM）参数是在启动Java应用程序时配置JVM的选项。这些参数可以帮助你调优JVM的性能，控制其运行时行为。以下是一些常用的JVM参数：

1. **-Xms**: 设置JVM初始堆大小。例如，-Xms256m设置初始堆大小为256兆字节。
2. **-Xmx**: 设置JVM最大堆大小。例如，-Xmx1024m设置最大堆大小为1024兆字节。通常，你应该根据你的应用程序的需求来设置这个参数。
3. **-Xss**: 设置线程栈大小。例如，-Xss1m设置线程栈大小为1兆字节。
4. **-XX:MaxPermSize**: 设置永久代的最大空间大小。注意，这个参数只在Java 8及更早版本中有用，因为在Java 8以后，Java移除了永久代，改为元空间（Metaspace）。
5. **-XX:MaxMetaspaceSize**: 设置元空间的最大空间大小。这个参数在Java 8及以后的版本中有用。
6. **-XX:+UseConcMarkSweepGC**: 启用CMS垃圾收集器。注意，这个参数在Java 9及以后的版本中已被废弃，因为默认的垃圾收集器在大多数情况下已经足够好。
7. **-XX:+UseG1GC**: 启用G1垃圾收集器。这个参数在Java 9及以后的版本中可用。
8. **-XX:+PrintGCDetails**: 打印详细的垃圾收集日志。
9. **-XX:+PrintGCTimeStamps**: 打印垃圾收集的时间戳。
10. **-XX:+PrintHeapAtGC**: 在每次垃圾收集时打印堆的使用情况。
11. **-XX:+UseCompressedOops**: 启用普通对象指针的压缩。这个参数在32位和64位JVM中都有用，它可以帮助减少内存使用。
12. **-XX:+UseCompressedClassPointers**: 启用类指针的压缩。这个参数在64位JVM中有用，它可以帮助减少内存使用。
13. **-XX:+DisableExplicitGC**: 禁用系统调用System.gc()，这个调用在默认情况下会触发一次Full GC，在一些情况下可能会影响性能。
14. **-XX:+ExplicitGCInvokesConcurrent**: 当系统调用System.gc()时，触发CMS GC而不是Full GC。
15. **-XX:+UseFastAccessorMethods**: 启用快速访问方法。这个参数可以提高性能，但是可能会增加内存使用。
16. **-XX:+UseParallelGC**: 启用并行垃圾收集器。这个参数在Java 8及更早的版本中有用，但在Java 9及以后的版本中已被废弃。

以上是一些常用的JVM参数，但是实际上还有很多其他的JVM参数可以用于调优和调试Java应用程序。你可以在Oracle的官方文档中找到完整的列表和详细的解释。

```
-Xms4g	初始堆大小4g
-Xmx4g	最大堆大小4g
-XX:NewSize=1g	设置年轻代大小=1g
-XX:MaxNewSize=2g	年轻代最大值2g
-Xss256k	每个线程的堆栈大小256k
-XX:NewRatio=2	年轻代(包括Eden和两个Survivor区)与年老代的比值(除去持久代)， -XX:NewRatio=2表示年轻代与年老代所占比值为1:2,年轻代占整个堆栈的1/3
-XX:SurvivorRatio=8	Eden区与Survivor区的大小比值，设置为8,则两个Survivor区与一个Eden区的比值为2:8,一个Survivor区占整个年轻代的1/10
-XX:MetaspaceSize=256m     元数据空间的初始大小256m，java8后才有，将永久代替换为元数据区
-XX:+DisableExplicitGC	关闭System.gc()
-XX:MaxTenuringThreshold=15	 垃圾最大年龄，如果将此值设置为一个较大值,则年轻代对象会在Survivor区进行多次复制,这样可以增加对象再年轻代的存活 时间,增加在年轻代即被回收的概率
-XX:+UseParNewGC	设置年轻代为并行收集
-XX:ParallelGCThreads=8 	并行收集器的线程数为8，此值最好配置与处理器数目相等
-XX:ConcGCThreads=8     CMS垃圾回收器并行线程线，推荐值为CPU核心数。
-XX:+UseConcMarkSweepGC	    老年代使用CMS内存收集
-XX:+UseBiasedLocking    启用一个优化了的线程锁，对于高并发访问很重要 ，太多的请求忙不过来它自动优化，对于各自长短不一的请求，出现的阻塞、排队现象，他自己优化。
-XX:+CMSParallelRemarkEnabled	降低标记停顿
-XX:CMSInitiatingOccupancyFraction=70	使用cms作为垃圾回收，使用70％后开始CMS收集
-XX:+PrintGCDetails	 输出形式:[GC [DefNew: 8614K->781K(9088K), 0.0123035 secs] 118250K->113543K(130112K), 0.0124633 secs]
-XX:+PrintGCTimeStamps  打印Gc时间戳
-Xloggc:logs/Gc.log	把相关日志信息记录到logs/GcLog.log文件以便分析
-XX:+HeapDumpOnOutOfMemoryError 出现堆内存溢出时，自动导出堆内存 dump 快照
-XX:HeapDumpPath=logs 设置导出的堆内存快照的存放地址为logs
-XX:+CMSClassUnloadingEnabled 开启回收Perm永生代
-XX:+UseCompressedClassPointers（压缩开关）
-XX:CompressedClassSpaceSize=512m（Compressed Class Space 空间大小限制）。
```

## jps
>jps 全称为`Java Virtual Machine Process Status Tool`，是 JDK 提供的一个查看当前用户有权访问的主机上正在运行的 Java 进程信息的命令行工具，通过读取特定目录下的相关文件来获取信息。

**语法：** `jps [options] [hostid]`

* options: 命令参数，可以控制输出格式
* hostid: 指定特定主机，可以是ip地址或域名，也可以指定具体协议和端口

**参数说明：**
* -q：只输出PID
* -m：输出传递给main方法的参数
* -l：输出应用程序主类的完整包名或应用程序jar文件的完整路径名
* -v：输出传递给jvm的参数
* -V：通过 flags 文件（.hotspotrc 文件或 -XX:Flags=< filename > 参数指定的文件）输出传递给 JVM 的参数。本参数不常用。

## jinfo
    jinfo 是 JDK 自带的一个命令行工具，用于查看和调整正在运行的 Java 进程的各种参数和选项。

**语法：**
```
jinfo -help
Usage:
    jinfo [option] <pid>
        (to connect to running process)
    jinfo [option] <executable <core>
        (to connect to a core file)
    jinfo [option] [server_id@]<remote server IP or hostname>
        (to connect to remote debug server)

where <option> is one of:
    -flag <name>         to print the value of the named VM flag
    -flag [+|-]<name>    to enable or disable the named VM flag
    -flag <name>=<value> to set the named VM flag to the given value
    -flags               to print VM flags
    -sysprops            to print Java system properties
    <no option>          to print both of the above
    -h | -help           to print this help message
```
* no option：输出全部的参数和系统属性
* -flag name：输出对应名称的参数
* -flag [+|-]name：开启或者关闭对应名称的参数
* -flag name=value：动态修改对应名称的参数
* -flags：输出全部的参数
* -sysprops：输出系统属性


## jstack
>jstack是JDK自带的一种堆栈跟踪工具，可用于生成当前JVM的线程快照。线程快照是当前JVM内每一条线程正在执行的方法堆栈集合，生成线程快照的主要目的是定位线程出现长时间停顿的原因，如线程间死锁，死循环，请求外部资源导致长时间等待等问题。线程出现停顿的时候通过jstack来查看各个线程的调用堆栈，就可以知道没有响应的线程到底在后台执行什么任务，或者等待什么资源。如果java程序崩溃生成core文件，jstack工具可以用来获取core文件的java stack和native stack的信息，从而知道java程序是如何崩溃在程序何处发生问题。另外jstack工具可以attach到正在运行的java程序中，看到当时运行的java程序的java stack和native stack的信息，如果现在运行的java程序呈现hung的状态，jstack是非常有用的。

    简而言之，jstack主要用来查看java线程的调用堆栈，可以用来分析线程问题（如死锁，死循环，CPU占用过高）

**语法：**
```
jstack -help
Usage:
    jstack [-l] <pid>
        (to connect to running process)
    jstack -F [-m] [-l] <pid>
        (to connect to a hung process)
    jstack [-m] [-l] <executable> <core>
        (to connect to a core file)
    jstack [-m] [-l] [server_id@]<remote server IP or hostname>
        (to connect to a remote debug server)

Options:
    -F  to force a thread dump. Use when jstack <pid> does not respond (process is hung)
    -m  to print both java and native frames (mixed mode)
    -l  long listing. Prints additional information about locks
    -h or -help to print this help message
```
* -F：当正常输出的请求不被响应时，强制输出线程堆栈
* -m：如果调用到本地方法的话，加上此参数可以显示本地方法的堆栈
* -l：最常用的一个参数，除堆栈外，显示关于锁的附加信息，在发生死锁时可以用`jstack -l pid`来观察锁持有状态

## jstat
>jstat是JDK自带的一个命令行工具，全称是`Java Virtual Machine statistics monitoring tool`，可以用来监视和分析java应用程序的内存使用和性能情况。jstat命令可以显示有关java堆和非堆内存使用情况、类加载、垃圾回收和编译器等方面的消息

**语法：**
```
Usage: jstat -help|-options
       jstat -<option> [-t] [-h<lines>] <vmid> [<interval> [<count>]]

Definitions:
  <option>      An option reported by the -options option
  <vmid>        Virtual Machine Identifier. A vmid takes the following form:
                     <lvmid>[@<hostname>[:<port>]]
                Where <lvmid> is the local vm identifier for the target
                Java virtual machine, typically a process id; <hostname> is
                the name of the host running the target Java virtual machine;
                and <port> is the port number for the rmiregistry on the
                target host. See the jvmstat documentation for a more complete
                description of the Virtual Machine Identifier.
  <lines>       Number of samples between header lines.
  <interval>    Sampling interval. The following forms are allowed:
                    <n>["ms"|"s"]
                Where <n> is an integer and the suffix specifies the units as
                milliseconds("ms") or seconds("s"). The default units are "ms".
  <count>       Number of samples to take before terminating.
  -J<flag>      Pass <flag> directly to the runtime system.

jstat -options:
-class
-compiler
-gc
-gccapacity
-gccause
-gcmetacapacity
-gcnew
-gcnewcapacity
-gcold
-gcoldcapacity
-gcutil
-printcompilation
```
* option=-class：显示类加载情况
* option=-compiler：显示JIT编译器统计信息
* option=-gc：显示垃圾回收统计信息
* option=-gccapacity：显示垃圾回收堆内存使用情况
* option=-gccause：与gcutil基本一致，但是会额外输出最近一次GC的原因
* option=-gcmetacapacity：显示垃圾回收非堆内存使用情况
* option=-gcnew：显示新生代垃圾回收统计信息
* option=-gcnewcapacity：显示新生代垃圾回收堆内存使用情况
* option=-gcold：显示老年代垃圾回收统计信息
* option=-gcoldcapacity：显示老年代垃圾回收堆内存使用情况
* option=-gcutil：显示垃圾回收堆内存使用情况总览
* option=-printcompilation：显示JIT编译器编译情况
* -t：输出时间戳
* -J：输出完整的JVM内部信息
* vmid：java虚拟机进程id或进程名
* interval：指定采样间隔时间，默认单位毫秒。也可以用单位s/ms指定：10s/100ms
* count：指定采样次数，默认是无限次


## jmap
>jmap是JDK自带的一个命令行工具，可以用于生成Java Heap Dump文件，以及查看Java进程中的内存使用情况

**语法：**
```
Usage:
    jmap [option] <pid>
        (to connect to running process)
    jmap [option] <executable <core>
        (to connect to a core file)
    jmap [option] [server_id@]<remote server IP or hostname>
        (to connect to remote debug server)

where <option> is one of:
    <none>               to print same info as Solaris pmap
    -heap                to print java heap summary
    -histo[:live]        to print histogram of java object heap; if the "live"
                         suboption is specified, only count live objects
    -clstats             to print class loader statistics
    -finalizerinfo       to print information on objects awaiting finalization
    -dump:<dump-options> to dump java heap in hprof binary format
    dump-options:
                           live         dump only live objects; if not specified,
                                        all objects in the heap are dumped.
                           format=b     binary format
                           file=<file>  dump heap to <file>
                         Example: jmap -dump:live,format=b,file=heap.bin <pid>
    -F                   force. Use with -dump:<dump-options> <pid> or -histo
                         to force a heap dump or histogram when <pid> does not
                         respond. The "live" suboption is not supported
                         in this mode.
    -h | -help           to print this help message
    -J<flag>             to pass <flag> directly to the runtime system
```
**option：**
* -heap：打印java堆概要信息，包括使用的GC算法，堆配置参数和各代中堆内存使用情况
* -histo[:live]：打印Java堆中对象直方图，通过该图可以获取每个class的对象数目，占用内存大小和类全名信息，带上:live，则只统计活着的对象
* -clastats：打印类加载器的统计信息
* -finalizerinfo：打印等待回收的对象信息
* -dump：以hprof二进制格式将java堆信息输出到文件内，该文件可以用jprofiler、visualVM或jhat等工具查看

**dump-options：**
* live：只输出活着的对象，不指定则输出堆中所有对象
* format=b：指定输出二进制
* file=file：指定文件存储 例如：jmap -dump:live,format=b,file=D:\heap.bin
* -F：-F 与-dump: 或 -histo 一起使用，当没有响应时，强制执行；注意：不支持live子选项

## jhat
>jhat 全称为 `Java Virtual Machine Heap Analysis Tool`，即虚拟机堆转储快照分析工具。jhat用于分析heapdump文件，它会建立一个http/html的服务器，让用户可以在浏览器上查看分析结果。jhat一般与jmap搭配使用，用于分析jmap生成的堆转储快照。jhat是一个命令行工具，使用起来比较简单，但功能比较简陋。如果条件允许的话，建议使用jprofiler或者IBM的HeapAnalyzer等功能强大的工具来分析heapdump文件

```
Usage:  jhat [-stack <bool>] [-refs <bool>] [-port <port>] [-baseline <file>] [-debug <int>] [-version] [-h|-help] <file>

        -J<flag>          Pass <flag> directly to the runtime system. For
                          example, -J-mx512m to use a maximum heap size of 512MB
        -stack false:     Turn off tracking object allocation call stack.
        -refs false:      Turn off tracking of references to objects
        -port <port>:     Set the port for the HTTP server.  Defaults to 7000
        -exclude <file>:  Specify a file that lists data members that should
                          be excluded from the reachableFrom query.
        -baseline <file>: Specify a baseline object dump.  Objects in
                          both heap dumps with the same ID and same class will
                          be marked as not being "new".
        -debug <int>:     Set debug level.
                            0:  No debug output
                            1:  Debug hprof file parsing
                            2:  Debug hprof file parsing, no server
        -version          Report version number
        -h|-help          Print this help and exit
        <file>            The file to read

For a dump file that contains multiple heap dumps,
you may specify which dump in the file
by appending "#<number>" to the file name, i.e. "foo.hprof#3".

All boolean options default to "true"
```

* -J< flag >：因为 jhat 命令实际上会启动一个 JVM 来执行，通过 -J 可以在启动 JVM 时传入一些启动参数。例如，-J-Xmx512m 指定运行 jhat 的 JVM 使用的最大堆内存为 512 MB。 如果需要使用多个 JVM 启动参数，则传入多个 -Jxxxxxx。
* -stack false|true：关闭跟踪对象分配调用堆栈。如果分配位置信息在堆转储中不可用，则必须将此标志设置为 false。默认值为 true。
* -refs false|true：关闭对象引用跟踪。默认情况下，返回的指针是指向其他特定对象的对象，如反向链接或输入引用(referrers or incoming references),，会统计/计算堆中的所有对象。
* -port port-number：设置 jhat HTTP server 的端口号，默认值 7000。
* -exclude exclude-file：指定对象查询时需要排除的数据成员列表文件。 例如，如果文件列出了 java.lang.String.value，那么当从某个特定对象 Object o 计算可达的对象列表时，引用路径涉及 java.lang.String.value 的都会被排除。
* -baseline exclude-file：指定一个基准堆转储(baseline heap dump)。 在两个 heap dump 文件中有相同 object ID 的对象会被标记为不是新的(marked as not being new)，其他对象被标记为新的(new)。在比较两个不同的堆转储时很有用。
* -debug int：设置 debug 级别，0 表示不输出调试信息。 值越大则表示输出更详细的 debug 信息。
* -version：启动后只显示版本信息就退出。

## jconsole
    jconsole是一款对JVM的可视化监视管理工具，通过它我们可以实时地监视JVM的内存、线程、类加载等信息的变化趋势。直接输入jconsule就可以打开。

    jconsole启动后有一个选择JVM进程的界面，选择一个JVM后即可看到界面。

    如果要连接一个远程机器上的JVM，那么需要在目标机器的JVM上增加以下参数：
```
-Dcom.sun.management.jmxremote
-Dcom.sun.management.jmxremote.ssl=false
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.port=<port>
-Djava.rmi.server.hostname=<ip>
```
>如果想要使用密码认证和ssl保证通信安全，请自行搜索。

## JVisualVM
    visualVM是一个类似jconsole，但是比jconsole的功能更强大丰富的JVM监视工具，还可以用来分析jmap的堆转储快照文件。
    它也可以连接远程JVM，方法与jconsole的远程JVM一样。

## JMC
> JMC，Java Mission Control，是另一个很强大的JVM监视工具，和visualVM、jconsole一样，它可以监视JVM的各种数据。除此以外，它还提供了强大的飞行记录器功能，记录一段时间内JVM的各种信息，包括内存、代码、线程、IO、事件等等的记录，然后基于这些信息做性能分析


## javac

## javadoc

## JVM工具总结
>JVM运维与调试工具当然并不是仅仅只有本章节所列举的这些，但一般而言，这些工具掌握部分也就满足平时的需要了。这里对它们进行一个简单的总结。

* 当你只是简单地查看JVM运行时的状况时，你可以直接使用JDK自带的那些工具命令，比如jps、jinfo等等。
* 当你需要在OOM时查看内存泄露原因时，可以直接在JVM参数中配置OOM自动dump堆转储快照文件，并配合jmap等工具手动或定时周期性地dump堆快照。
* 当你想实时监视JVM的内存、线程、CPU等资源消耗趋势时，你可以使用jconsole、visualVM、JMC等工具。
* 当你想全面监视JVM各种事件信息，包括磁盘 IO、GC、线程 sleep、线程 wait、Socket read/write 等等，且不想对JVM性能带去影响时，你可以通过JMC录制JFR飞行记录，并在JMC中查看报告。
* 当你需要在方法层面上监视跟踪其调用链路，耗时及返回值时，你可以使用arthas这样的在线JVM调试工具。