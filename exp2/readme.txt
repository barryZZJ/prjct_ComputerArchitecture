```
.
|-- doc			文档
|-- soc_axi_lite_loongson	soc环境
|   |-- rtl				rtl源码
|   |   |-- CONFREG
|   |   |-- axi_wrap
|   |   |-- myCPU			CPU源码目录
|   |   |-- ram_wrap
|   |   `-- xilinx_ip
|   |-- run_vivado		
|   |   `-- mycpu_prj1			vivado工程目录
|   `-- testbench			仿真顶部文件
|-- soft			软件环境
|   `-- cache_lab
|       |-- bench
|       |-- include
|       |-- lib
|       `-- obj
`-- traces			trace文件目录

18 directories

```

## 改动

1. 2020/11/13

   1. 修改了soft/cache_lab/bench/下的shell1.c和matrix_mult.c中打开trace和关闭trace的位置。并重新编译获得obj。

   2. 重新生成traces/cache_lab_trace.txt。并手动将pc=9fc00fa4-9fc00fc4的trace_cmp_flag（第一个数）置0，否则9fc00fb8和9fc00fbc会比对失败（即使关闭了trace，获得时间时get_count修改了一些寄存器，并保留了下来，导致这里的指令与时间有关）

   3. 修改testbench文件mycpu_tb.v的逻辑。

      原来的比对逻辑是当CPU写回阶段写寄存器时，读取trace文件并跳过trace_cmp_flag为0的行直到遇到为1的行，再和CPU写入的数据进行对比。

      修改为，读取trace文件一行内容，并根据读到的trace_cmp_flag决定是否与CPU读到的数据比较。