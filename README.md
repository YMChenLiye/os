#               clyos
-----
## 实现了内核线程,特权级变化，用户进程，任务调度，内存管理，文件系统，fork，exec，父子间进程通信等功能
## 默认的shell支持外部命令，管道操作

=
=
#### 支持的系统调用如下：
 *   SYS_GETPID,
 *   SYS_WRITE,
 *   SYS_MALLOC,
 *   SYS_FREE,
 *   SYS_FORK,
 *   SYS_READ,
 *   SYS_PUTCHAR,
 *   SYS_CLEAR,
 *   SYS_GETCWD,
 *   SYS_OPEN,
 *   SYS_CLOSE,
 *   SYS_LSEEK,
 *   SYS_UNLINK,
 *   SYS_MKDIR,
 *   SYS_OPENDIR,
 *   SYS_CLOSEDIR,
 *   SYS_CHDIR,
 *   SYS_RMDIR,
 *   SYS_READDIR,
 *   SYS_REWINDDIR,
 *   SYS_STAT,
 *   SYS_PS,
 *   SYS_EXECV,
 *   SYS_EXIT,
 *   SYS_WAIT,
 *   SYS_PIPE,
 *   SYS_FD_REDIRECT,
 *   SYS_HELP


#### 系统跑在bochs虚拟机上，模拟出了两个硬盘，第一个硬盘是一个裸盘，MBR、loader、内核都是存放在这块硬盘上的
#### 第二块硬盘上我们将其格式化，实现了文件系统
