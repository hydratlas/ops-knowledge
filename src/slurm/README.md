# Slurm（シングルノード構成）

Slurmは、クラスタ環境でのジョブスケジューリングと資源管理を行うためのオープンソースツールである。高性能計算（HPC）環境での計算リソースの効率的な利用を実現する。

本ドキュメントは**シングルノード構成**（1台のマシンでコントローラーと計算ノードを兼用）での手動セットアップ手順を説明する。マルチノード構成については、以下のAnsibleロールを参照すること。

- `slurm_common`：ログインノード・計算ノード共通（変数バリデーション・JWT鍵配置）
- `slurm_ctrl`：コントローラーノード用
- `slurm_node`：計算ノード用（slurm_commonに依存）
- `slurm_login`：ログインノード用（slurm_commonに依存）

## 【オプション】直接ビルドする場合
基本的には[Slurm Workload Manager - Quick Start Administrator Guide](https://slurm.schedmd.com/quickstart_admin.html)に従って、ビルドする。

[Download Slurm - SchedMD](https://www.schedmd.com/download-slurm/)でダウンロードしたいバージョンを調べる。バージョンはXX.YY.Z形式をとっている。ダウンロードURLは[https://download.schedmd.com/slurm/slurm-24.05-latest.tar.bz2]()というようにマイナーバージョンにあたるZ部分は`-latest`とすれば最新のマイナーバージョンをダウンロードできる。

具体的なビルド方法は[hydratlas/slurm-building](https://github.com/hydratlas/slurm-building)を参照。

パッケージの対応関係は以下のとおりであると推定される。`slurm-wlm-basic-plugins`はほかのパッケージからの依存関係によって自動的にインストールされるが、`slurm-smd`は明示的にインストールする必要があると思われる。
| Debian or Ubuntu repository | direct build                             |
| --------------------------- | ---------------------------------------- |
| slurm-wlm-basic-plugins     | slurm-smd_\<version>_amd64.deb           |
| slurm-client                | slurm-smd-client_\<version>_amd64.deb    |
| slurmd                      | slurm-smd-slurmd_\<version>_amd64.deb    |
| slurmctld                   | slurm-smd-slurmctld_\<version>_amd64.deb |
| slurmdbd                    | slurm-smd-slurmdbd_\<version>_amd64.deb  |
| sackd                       | slurm-smd-sackd_\<version>_amd64.deb     |

## 【オプション】データベースのインストール・設定
データベースデーモン（slurmdbd）を使う場合のみ。
```bash
sudo apt-get install -y mariadb-server

sudo mysql_secure_installation

sudo mariadb -u root -p

create database slurm_acct_db;
show databases;
create user 'slurm'@'localhost' identified by '<password>';
select user,host from mysql.user;
grant all on slurm_acct_db.* TO 'slurm'@'localhost';
FLUSH PRIVILEGES;
quit;

mariadb -u slurm -h localhost -p

quit;
```

## 各種ノードへのインストール
Slurmの各種ノードは、ログインノード、ヘッドノードおよび計算ノードに分かれる。以下のような構成だと思われるが詳細は未検証。また、すべてインストールすればシングルノード構成にできる。
- ログインノード（ジョブ投入）：slurm-clientパッケージをインストール。sackdパッケージをインストール（あるいはslurmdパッケージをインストールの上でStateをDownにする）
- ヘッドノード（ジョブ管理）：slurmctldパッケージをインストール
- 計算ノード：slurmdパッケージをインストール

### ヘッドノード（ログインノード兼用）へのインストール
```bash
sudo apt-get install -y slurmctld slurmdbd
```
データベースデーモン（slurmdbd）はオプション。slurmctldの依存関係でslurm-clientもインストールされる。

### 計算ノードへのインストール
```bash
sudo apt-get install -y slurmd
```

## 設定の下準備として変数を設定
```bash
if [ -e /etc/slurm-llnl ]; then
  ETC_PATH=/etc/slurm-llnl
elif [ -e /etc/slurm ]; then
  ETC_PATH=/etc/slurm
else
  ETC_PATH="(null)"
fi &&
if [ -e /var/log/slurm-llnl ]; then
  VAR_LOG_PATH=/var/log/slurm-llnl
elif [ -e /var/log/slurm ]; then
  VAR_LOG_PATH=/var/log/slurm
else
  VAR_LOG_PATH="(null)"
fi &&
if [ -e /var/lib/slurm-llnl ]; then
  VAR_LIB_PATH=/var/lib/slurm-llnl &&
  RUN_PATH=/run/slurm-llnl
elif [ -e /var/lib/slurm ]; then
  VAR_LIB_PATH=/var/lib/slurm &&
  RUN_PATH=/run/slurm
else
  VAR_LIB_PATH="(null)" &&
  RUN_PATH="(null)"
fi &&
echo "ETC_PATH: $ETC_PATH" &&
echo "VAR_LOG_PATH: $VAR_LOG_PATH" &&
echo "VAR_LIB_PATH: $VAR_LIB_PATH" &&
echo "RUN_PATH: $RUN_PATH"
```

## PIDファイルの置き場所を作る
```bash
sudo tee "/etc/tmpfiles.d/slurm.conf" << EOS > /dev/null &&
d $RUN_PATH 0775 slurm slurm -
EOS
sudo systemd-tmpfiles --create /etc/tmpfiles.d/slurm.conf
```

## PIDファイルの場所をsystemdに伝える（Ubuntu 20.04以前だけ）
```bash
sudo mkdir -p /etc/systemd/system/slurmdbd.service.d &&
sudo mkdir -p /etc/systemd/system/slurmctld.service.d &&
sudo mkdir -p /etc/systemd/system/slurmd.service.d &&
sudo tee "/etc/systemd/system/slurmdbd.service.d/custom.conf" << EOS > /dev/null &&
[Service]
PIDFile=$RUN_PATH/slurmdbd.pid
EOS
sudo tee "/etc/systemd/system/slurmctld.service.d/custom.conf" << EOS > /dev/null &&
[Service]
PIDFile=$RUN_PATH/slurmctld.pid
EOS
sudo tee "/etc/systemd/system/slurmd.service.d/custom.conf" << EOS > /dev/null &&
[Service]
PIDFile=$RUN_PATH/slurmd.pid
EOS
sudo systemctl daemon-reload
```

## 【オプション】データベースデーモンの設定ファイルを設置
データベースデーモンを使う場合のみ。
```bash
sudo tee "$ETC_PATH/slurmdbd.conf" << EOS > /dev/null &&
# https://github.com/SchedMD/slurm/blob/master/etc/slurmdbd.conf.example
#
# Archive info
#ArchiveJobs=yes
#ArchiveDir="/tmp"
#ArchiveSteps=yes
#ArchiveScript=
#JobPurge=12
#StepPurge=1
#
# Authentication info
AuthType=auth/munge
#AuthInfo=/var/run/munge/munge.socket.2
#
# slurmDBD info
DbdAddr=localhost
DbdHost=localhost
#DbdPort=7031
SlurmUser=slurm
#MessageTimeout=300
DebugLevel=verbose
#DefaultQOS=normal,standby
LogFile=$VAR_LOG_PATH/slurmdbd.log
PidFile=$RUN_PATH/slurmdbd.pid
#PluginDir=$VAR_LIB_PATH
#PrivateData=accounts,users,usage,jobs
#TrackWCKey=yes
#
# Database info
StorageType=accounting_storage/mysql
#StorageHost=localhost
#StoragePort=1234
StoragePass=<password>
StorageUser=slurm
#StorageLoc=slurm_acct_db
EOS
sudo chmod 600 "$ETC_PATH/slurmdbd.conf" &&
sudo chown slurm:slurm "$ETC_PATH/slurmdbd.conf"
```

## Slurmの設定ファイルを設置
AccountingStorageType=accounting_storage/noneのためデータベースデーモンは使用していない。使用する場合は、accounting_storage/slurmdbdにする。また一番下のほうの`NodeName=localhost`で始まる行は`slurmd -C`を実行した結果で置き換える。

```bash
sudo tee "$ETC_PATH/cgroup.conf" << EOS > /dev/null &&
# https://github.com/SchedMD/slurm/blob/master/etc/cgroup.conf.example
###
#
# Slurm cgroup support configuration file
#
# See man slurm.conf and man cgroup.conf for further
# information on cgroup configuration parameters
#--
ConstrainCores=yes
ConstrainDevices=yes
ConstrainRAMSpace=yes
ConstrainSwapSpace=yes
EOS
sudo tee "$ETC_PATH/slurm.conf" << EOS > /dev/null &&
# https://github.com/SchedMD/slurm/blob/master/etc/slurm.conf.example
#
# Example slurm.conf file. Please run configurator.html
# (in doc/html) to build a configuration file customized
# for your environment.
#
#
# slurm.conf file generated by configurator.html.
# Put this file on all nodes of your cluster.
# See the slurm.conf man page for more information.
#
ClusterName=local-cluster
SlurmctldHost=localhost
#SlurmctldHost=
#
#DisableRootJobs=NO
#EnforcePartLimits=NO
#Epilog=
#EpilogSlurmctld=
#FirstJobId=1
#MaxJobId=67043328
#GresTypes=
#GroupUpdateForce=0
#GroupUpdateTime=600
#JobFileAppend=0
#JobRequeue=1
#JobSubmitPlugins=lua
#KillOnBadExit=0
#LaunchType=launch/slurm
#Licenses=foo*4,bar
#MailProg=/bin/mail
#MaxJobCount=10000
#MaxStepCount=40000
#MaxTasksPerNode=512
MpiDefault=none
#MpiParams=ports=#-#
#PluginDir=
#PlugStackConfig=
#PrivateData=jobs
ProctrackType=proctrack/cgroup
#Prolog=
#PrologFlags=
#PrologSlurmctld=
#PropagatePrioProcess=0
#PropagateResourceLimits=
#PropagateResourceLimitsExcept=
#RebootProgram=
ReturnToService=2
SlurmctldPidFile=$RUN_PATH/slurmctld.pid
SlurmctldPort=6817
SlurmdPidFile=$RUN_PATH/slurmd.pid
SlurmdPort=6818
SlurmdSpoolDir=$VAR_LIB_PATH/slurmd
SlurmUser=slurm
#SlurmdUser=root
#SrunEpilog=
#SrunProlog=
StateSaveLocation=$VAR_LIB_PATH/checkpoint
SwitchType=switch/none
#TaskEpilog=
TaskPlugin=task/affinity
#TaskProlog=
#TopologyPlugin=topology/tree
#TmpFS=/tmp
#TrackWCKey=no
#TreeWidth=
#UnkillableStepProgram=
#UsePAM=0
#
#
# TIMERS
#BatchStartTimeout=10
#CompleteWait=0
#EpilogMsgTime=2000
#GetEnvTimeout=2
#HealthCheckInterval=0
#HealthCheckProgram=
InactiveLimit=0
KillWait=30
#MessageTimeout=10
#ResvOverRun=0
MinJobAge=300
#OverTimeLimit=0
SlurmctldTimeout=120
SlurmdTimeout=300
#UnkillableStepTimeout=60
#VSizeFactor=0
Waittime=0
#
#
# SCHEDULING
#DefMemPerCPU=0
#MaxMemPerCPU=0
#SchedulerTimeSlice=30
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core_Memory
#
#
# JOB PRIORITY
#PriorityFlags=
#PriorityType=priority/multifactor
#PriorityDecayHalfLife=
#PriorityCalcPeriod=
#PriorityFavorSmall=
#PriorityMaxAge=
#PriorityUsageResetPeriod=
#PriorityWeightAge=
#PriorityWeightFairshare=
#PriorityWeightJobSize=
#PriorityWeightPartition=
#PriorityWeightQOS=
#
#
# LOGGING AND ACCOUNTING
#AccountingStorageEnforce=0
#AccountingStorageHost=
#AccountingStoragePass=
#AccountingStoragePort=
AccountingStorageType=accounting_storage/none
#AccountingStorageUser=
#AccountingStoreFlags=
#JobCompHost=
#JobCompLoc=
#JobCompPass=
#JobCompPort=
JobCompType=jobcomp/none
#JobCompUser=
#JobContainerType=
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=info
SlurmctldLogFile=$VAR_LOG_PATH/slurmctld.log
SlurmdDebug=info
SlurmdLogFile=$VAR_LOG_PATH/slurmd.log
#SlurmSchedLogFile=
#SlurmSchedLogLevel=
#DebugFlags=
#
#
# POWER SAVE SUPPORT FOR IDLE NODES (optional)
#SuspendProgram=
#ResumeProgram=
#SuspendTimeout=
#ResumeTimeout=
#ResumeRate=
#SuspendExcNodes=
#SuspendExcParts=
#SuspendRate=
#SuspendTime=
#
#
# COMPUTE NODES
# slurmd -C
NodeName=localhost CPUs=1 Boards=1 SocketsPerBoard=1 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=512 State=UNKNOWN
PartitionName=debug Nodes=ALL Default=YES MaxTime=INFINITE State=UP
EOS
sudo chmod 644 "$ETC_PATH/slurm.conf" &&
sudo chown slurm:slurm "$ETC_PATH/slurm.conf"
```

## 【オプション】データベースデーモンの起動
データベースデーモンを使う場合のみ。
```bash
sudo systemctl stop slurmdbd.service &&
sudo systemctl enable --now slurmdbd.service &&
sudo systemctl status slurmdbd.service
```

## 管理デーモンの起動
```bash
sudo systemctl stop slurmctld.service &&
sudo systemctl enable --now slurmctld.service &&
sudo systemctl status slurmctld.service
```

## 計算デーモンの起動
```bash
sudo systemctl stop slurmd.service &&
sudo systemctl enable --now slurmd.service &&
sudo systemctl status slurmd.service
```

## Slurmのテスト実行
```bash
cd ~/ &&
tee hello-world.sh << EOS > /dev/null &&
#!/bin/bash
echo 'Hello, world!'
EOS
chmod 775 hello-world.sh &&
sbatch hello-world.sh
```
通常は`slurm-1.out`に結果（標準出力）が保存される。