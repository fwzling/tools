#!/usr/bin/env ruby

## Description: Script to analyze performance from UOS log
#               including CPU, GPU, VSLAM FPS, VSLAM navi latency, etc.
#               The analysis automatically clips the logs to interested time range aligned with uos_navigation.log
#
## Usage:       ruby perf-stat.rb /path/to/log/files/directory
#
## Dependency:
#               sudo apt-get install ruby
#               sudo gem install descriptive_statistics


## <uos_cv_framework.log>
# [20180818 16:04:54.762:INFO:uos_cv_framework] <uos_cv_vslam_wrapper.cc:691 vslam_callback()> cv_worker_0 vslam: X[-77173.6470] Y[4389742.5561] Z[-0.3944] Theta[4.3762] alpha[0.0248] beta[0.0132] Confidence[1.00] Stream[0] ret[0] tstamp[1534579494.762] FPS[12] Clocks[147 ms] Latency[0.152]

require 'descriptive_statistics'
require 'time'

DEBUG_Print = false  # default off

NAVIGATION_Log   = "uos_navigation.log"
CV_FRAMEWORK_Log = "slave_uos/uos_cv_framework.log"
SLAVE_Tegra_Log  = "slave_uos/tegra_stats.log"

# ----------------- Check Command Line Arguments ------------------- #
logPath = ARGV[0]
logPath = Dir.pwd if logPath.nil?

if not Dir.exist?(logPath)
    puts "ERROR: INPUT LOG directory does not exist. #{logPath}"
    exit 1
end

navigationLogPath  = File.join(logPath, NAVIGATION_Log)
cvFrameworkLogPath = File.join(logPath, CV_FRAMEWORK_Log)
slaveTegraLogPath  = File.join(logPath, SLAVE_Tegra_Log)

[navigationLogPath, cvFrameworkLogPath, slaveTegraLogPath].each do | fpath |
    if not File.exist?(fpath)
        puts "ERROR: #{fpath} not found"
        exit 1
    end
end

@naviStartTime, @naviEndTime = Time.new(2018), Time.new(2018)

# -------------------- Process Navigation Log ---------------------- #
## <uos_navigation.log>
# [20180823 16:45:25.734:INFO:uos_navigation] <fusion_test_replay.c:338 fusion_test_replay_write()> 
# navi_log_input_data:1 0 0.250 0.000 0.250 0.250 0.000 0.250 1.000 0.000 0.000 0.000 0.000 0.000 0.021 116.09891717 39.65650978 -77301.059 4390022.706 4.193 4 1 1 1 0 0.000 0.000 0.000 0.000 -77286.159 4390031.419 3.296 0.124 -77301.104 4390022.567 4.196 0.784 0.000 0.000 0.000 0.000 -77300.833 4390022.873 4.193 0.652 0.000 5.900 1 1 1.000 1.000 0.000 0.000 0.000 0.000 0.784 0.784 0.000 0.000 0.532 0.652 1534985125.650 1535013925.689 0.000 1535013916.906 1535013925.663 0.000 1535013925.621 1535013925.735 0 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0 38.051 -1000000.000 -1000000.000 0.000 0.000 0.000 -1.314 0.030 6.251 1.854 0.010 -0.019 0.000 0.000 0.000 -1.783 6.280 0.002 1 -77301.059 4390022.706 4.193 4 0.000 0.000 0.000 0.000 -77285.154 4390031.553 3.252 0.124 -77301.104 4390022.567 4.196 0.784 0.000 0.000 0.000 0.000 -77300.833 4390022.873 4.193 0.652 0 0 0 1 0 1 1.000
# Fields:
#       0 has_valid_loc_data
#       1 pure_est_by_roadmap_enabled
#       2 gps_weight
#       3 qrcode_weight
#       4 vslam_weight
#       5 lslam_carto_weight
#       6 vmap_weight
#       7 vslam1_weight
#       8 gps_weight_real
#       9 qrcode_weight_real
#      10 vslam_weight_real
#      11 lslam_carto_weight_real
#      12 vmap_weight_real
#      13 vslam1_weight_real
#      14 delta_time
#      15 GPS lng
#      16 GPS lat
#      17 GPS east
#      18 GPS north
#      19 GPS theta
#      20 GPS state
#      21 GPS valid
#      22 GPS pos_valid
#      23 GPS theta_valid
#      24 GPS is new data
#      25 QRCode east
#      26 QRCode north
#      27 QRCode theta
#      28 QRCode conf
#      29 VSLAM east
#      30 VSLAM north
#      31 VSLAM theta
#      32 VSLAM conf
#      33 LSLAM_C east
#      34 LSLAM_C north
#      35 LSLAM_C theta
#      36 LSLAM_C conf
#      37 VMAP east
#      38 VMAP north
#      39 VMAP theta
#      40 VMAP conf
#      41 VSLAM1 east
#      42 VSLAM1 north
#      43 VSLAM1 theta
#      44 VSLAM1 conf
#      45 CAN vel
#      46 CAN steer
#      47 CAN state
#      48 CAN valid state
#      49 GPS corr coef pos
#      50 GPS corr coef theta
#      51 QRCode corr coef pos
#      52 QRCode corr coef theta
#      53 VSLAM corr coef pos
#      54 VSLAM corr coef theta
#      55 LSLAM_C corr coef pos
#      56 LSLAM_C corr coef theta
#      57 VMAP corr coef pos
#      58 VMAP corr coef theta
#      59 VSLAM1 corr coef pos
#      60 VSLAM1 corr coef theta
#      61 GPS dev time
#      62 GPS host time
#      63 QRCode time
#      64 VSLAM time
#      65 LSLAM_C time
#      66 VMAP time
#      67 VSLAM1 time
#      68 ts_now
#      69 need_reset cmd
#      70 imu alpha
#      71 imu beta
#      72 imu theta
#      73 imu alpha rate
#      74 imu beta rate
#      75 imu theta rate
#      76 imu acc x
#      77 imu acc y
#      78 imu acc z
#      79 imu theta diff
#      80 imu state
#      81 GPS height
#      82 GPS alpha
#      83 GPS beta
#      84 QRCode height
#      85 QRCode alpha
#      86 QRCode beta
#      87 VSLAM height
#      88 VSLAM alpha
#      89 VSLAM beta
#      90 LSLAM_C height
#      91 LSLAM_C alpha
#      92 LSLAM_C beta
#      93 VMAP height
#      94 VMAP alpha
#      95 VMAP beta
#      96 VSLAM1 height
#      97 VSLAM1 alpha
#      98 VSLAM1 beta
#      99 odom state
#     100 last_valid GPS east
#     101 last_valid GPS north
#     102 last_valid GPS theta
#     103 last_valid GPS state
#     104 QRCode_ori east
#     105 QRCode_ori north
#     106 QRCode_ori theta
#     107 QRCode_ori conf
#     108 VSLAM_ori east
#     109 VSLAM_ori north
#     110 VSLAM_ori theta
#     111 VSLAM_ori conf
#     112 LSLAM_C_ori east
#     113 LSLAM_C_ori north
#     114 LSLAM_C_ori theta
#     115 LSLAM_C_ori conf
#     116 VMAP_ori east
#     117 VMAP_ori north
#     118 VMAP_ori theta
#     119 VMAP_ori conf
#     120 VSLAM1_ori east
#     121 VSLAM1_ori north
#     122 VSLAM1_ori theta
#     123 VSLAM1_ori conf
#     124 GPS updated state
#     125 QRCODE updated state
#     126 VSLAM updated state
#     127 LSLAM_C updated state
#     128 VMAP updated state
#     129 VSLAM_1 updated state
#     130 GPS conf
#     ...

NAVI_MAX_LATENCY_FOR_ERROR_STATE = 1.0  # 1 sec
NAVI_MAX_DATA_LOSS_TIME_VSLAM    = 0.3  # 300 ms
NAVI_INDEX_VSLAM_TS_0            = 64
NAVI_INDEX_VSLAM_TS_1            = 67
NAVI_INDEX_RECORD_TS             = 68
NAVI_RECORD_LINE_REGEXPR    = /^navi_log_input_data\:([\-\d\.\s]*)/ 
NAVI_TIMESTAMP_LINE_REGEXPR = /^\[([\d]{8}\s[\d\:\.]+)\:INFO\:uos_navigation\]/

def procNaviLog(logPath)
    foundFirstRecord = false
    recLineNum = 0
    vslam0_latency = []
    vslam1_latency = []

    File.readlines(logPath).each do | line |
        begin
            if matched = line.match(NAVI_TIMESTAMP_LINE_REGEXPR)
                ts = Time.parse(matched[1])
                @naviStartTime = ts unless foundFirstRecord
                @naviEndTime = ts
                foundFirstRecord = true
            elsif matched = line.match(NAVI_RECORD_LINE_REGEXPR)
                data = matched[1].split(' ')
                vslam0_ts = data[NAVI_INDEX_VSLAM_TS_0].to_f
                vslam1_ts = data[NAVI_INDEX_VSLAM_TS_1].to_f
                rec_ts    = data[NAVI_INDEX_RECORD_TS].to_f
                la_0 = rec_ts - vslam0_ts
                la_1 = rec_ts - vslam1_ts
                puts "Processing record: [#{la_0}] [#{la_1}]" if DEBUG_Print
                recLineNum += 1
                vslam0_latency << la_0 if la_0 < NAVI_MAX_LATENCY_FOR_ERROR_STATE 
                vslam1_latency << la_1 if la_1 < NAVI_MAX_LATENCY_FOR_ERROR_STATE 
            end
        rescue Exception => e
            puts e.message
            next
        end 
    end
    puts "Number of records: [#{recLineNum}, #{vslam0_latency.count}, #{vslam1_latency.count}]"
    puts "Time range: [#{@naviStartTime}, #{@naviEndTime}]"
    [ ["VSLAM_0 Latency", vslam0_latency],
      ["VSLAM_1 Latency", vslam1_latency] ].each do | subject, stat |
        next if stat.empty?
        puts subject 
        puts "  Max:                #{stat.sort.last.round(3)}"
        puts "  P95:                #{stat.percentile(95).round(3)}"
        puts "  P90:                #{stat.percentile(90).round(3)}"
        puts "  Average:            #{stat.mean.round(3)}"
        puts "  StandardDeviation:  #{stat.standard_deviation.round(3)}"
        puts "  %[<#{NAVI_MAX_DATA_LOSS_TIME_VSLAM}]:            #{stat.percentile_rank(NAVI_MAX_DATA_LOSS_TIME_VSLAM).round(3)}"
        puts "  Range:              #{stat.range.round(3)}"
    end
end

# -------------------- Process CvFramework Log --------------------- #
## <uos_cv_framework.log>
# [20180818 16:04:54.762:INFO:uos_cv_framework] <uos_cv_vslam_wrapper.cc:691 vslam_callback()> cv_worker_0 vslam: X[-77173.6470] Y[4389742.5561] Z[-0.3944] Theta[4.3762] alpha[0.0248] beta[0.0132] Confidence[1.00] Stream[0] ret[0] tstamp[1534579494.762] FPS[12] Clocks[147 ms] Latency[0.152]

CV_VSLAM_LINE_REGEXPR = /^\[(\d{8}\s[\d\:\.]+)\:INFO\:uos_cv_framework\].*Stream\[(\d)\].*FPS\[(\d+)\].*Clocks\[(\d+)\sms\].*Latency\[([\d\.]+)\]$/

def procCvFrameworkLog(logPath)
    fpsStream_0,     fpsStream_1     = [], []
    clockStream_0,   clockStream_1   = [], []
    latencyStream_0, latencyStream_1 = [], []

    File.readlines(logPath).each do | line |
        begin
            if matched = line.match(CV_VSLAM_LINE_REGEXPR)
                timestamp  = Time.parse(matched[1])
                next unless timestamp.between?(@naviStartTime, @naviEndTime)
                stream_id = matched[2].to_i
                fps       = matched[3].to_i
                clock     = matched[4].to_i
                latency   = matched[5].to_f
                puts "[#{timestamp}] Stream[#{stream_id}] FPS[#{fps}] Clock[#{clock}] Latency[#{latency}]" if DEBUG_Print
                if stream_id == 0
                    fpsStream_0 << fps
                    clockStream_0 << clock
                    latencyStream_0 << latency
                elsif stream_id == 1
                    fpsStream_1 << fps
                    clockStream_1 << clock
                    latencyStream_1 << latency
                else
                    puts "[ERROR] unexpected stream number"
                    exit 1
                end
            end
        rescue Exception => e
            puts e.message
            next
        end
    end
    puts "Number of records:"
    puts "    Stream[0]: #{fpsStream_0.count}"
    puts "    Stream[1]: #{fpsStream_1.count}"

    [ [fpsStream_0, "Stream[0].FPS"],
      [clockStream_0, "Stream[0].Clock"],
      [latencyStream_0, "Stream[0].Latency"],
      [fpsStream_1, "Stream[1].FPS"],
      [clockStream_1, "Stream[1].Clock"],
      [latencyStream_1, "Stream[1].Latency"],
    ].each do | stat, subject |
        next if stat.empty?
        puts ""
        puts subject 
        puts "  Min:                #{stat.sort.first.round(3)}"
        puts "  Max:                #{stat.sort.last.round(3)}"
        puts "  P10:                #{stat.percentile(10).round(3)}"
        puts "  P90:                #{stat.percentile(90).round(3)}"
        puts "  Average:            #{stat.mean.round(3)}"
        puts "  StdDev:             #{stat.standard_deviation.round(3)}"
    end
end

# -------------------- Process Slave Tegra Log --------------------- #
## <tegra_stats.log>
# [2018-08-23 16:30:36] : RAM 4923/7850MB (lfb 360x4MB) CPU [33%@2034,42%@2033,100%@2036,22%@2035,61%@2034,43%@2035] EMC_FREQ 14%@1600 GR3D_FREQ 22%@1300 APE 150 MTS fg 0% bg 0% BCPU@53C MCPU@53C GPU@59C PLL@53C AO@50.5C Tboard@48C Tdiode@49.5C PMIC@100C thermal@52.1C VDD_IN 9273/9056 VDD_CPU 3716/3302 VDD_GPU 1430/1586 VDD_SOC 714/705 VDD_WIFI 0/0 VDD_DDR 1148/1198

TEGRA_RECORD_LINE_REGEXPR = /^\[([\d\s:-]*).*CPU\s\[(\d*)\%@\d+,(\d*)\%@\d+,(\d*)\%@\d+,(\d*)\%@\d+,(\d*)\%@\d+,(\d*)\%@\d+\].*GR3D_FREQ\s(\d+)/

def procSlaveTegraLog(logPath)
    usageCPUAll = []
    usageGPUAll = []
    File.readlines(logPath).each do | line |
        begin
            if matched = line.match(TEGRA_RECORD_LINE_REGEXPR)
                timestamp  = Time.parse(matched[1])
                next unless timestamp.between?(@naviStartTime, @naviEndTime)
                usage_CPU0 = matched[2].to_i
                usage_CPU1 = matched[3].to_i
                usage_CPU2 = matched[4].to_i
                usage_CPU3 = matched[5].to_i
                usage_CPU4 = matched[6].to_i
                usage_CPU5 = matched[7].to_i
                usage_GPU  = matched[8].to_i
                puts "[#{timestamp}] #{usage_CPU0} #{usage_CPU1} #{usage_CPU2} #{usage_CPU3} #{usage_CPU4} #{usage_CPU5} #{usage_GPU}" if DEBUG_Print
                usageCPUAll << (usage_CPU0 + usage_CPU1 + usage_CPU2 + usage_CPU3 + usage_CPU4 + usage_CPU5).to_f / 600
                usageGPUAll << usage_GPU.to_f
            end
        rescue Exception => e
            puts e.message
            next
        end
    end

    puts "CPU or GPU data empty" and return if usageCPUAll.empty? || usageGPUAll.empty?
    puts "Analyzed #{usageCPUAll.count} CPU recrods and #{usageGPUAll.count} GPU records"
    [ ["CPU Stat.", usageCPUAll],
      ["GPU Stat.", usageGPUAll] ].each do | subject, stat |
        next if stat.empty?
        puts subject 
        puts "  Max:                #{stat.sort.last.round(3)}"
        puts "  P95:                #{stat.percentile(95).round(3)}"
        puts "  P90:                #{stat.percentile(90).round(3)}"
        puts "  Average:            #{stat.mean.round(3)}"
        puts "  StdDev:             #{stat.standard_deviation.round(3)}"
    end
end

# -------------------- main --------------------- #

puts " ---------------- Process navigation log ---------------- "
procNaviLog(navigationLogPath)
puts " * "

puts " ---------------- Process tegra log ---------------- "
procSlaveTegraLog(slaveTegraLogPath)
puts " * "

puts " ---------------- Process cv_framework log ---------------- "
procCvFrameworkLog(cvFrameworkLogPath)
puts " * "
