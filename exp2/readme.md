vivado version: 2019.2

代码在soc_axi_lite_loongson/rtl/myCPU里

|写直达（示例）|写回+写分配| 写回+写分配+2路组相连 |写回+写分配+4路组相连+伪LRU |
|--|--|--|--|
|`d_cache_wt.v`|`d_cache_wb.v`|`d_cache_wb_2way.v`|`d_cache_wb_4way_fLRU.v`|

记得跑仿真时把要仿真的那个模块名字改成`d_cache`，其他的三个改成别的