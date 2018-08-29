#!/usr/bin/env ruby

## Description: Script to analyze VSLAM latency in navigation 
#
## Usage:       ruby navi_vslam.rb navigation.log

### Important information in navigation log
# (1) measurement input flags:
#     (GPS QRCode VSLAM VSLAM_camera2 LSLAM_carto Visualmap): 0 0 1 1 0 0
# (2) input data fields:
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

## Interesting line example:
#
# navi_log_input_data:1 0 0.000 0.000 0.500 0.000 0.000 0.500 0.000 0.000 0.500 0.000 0.000 0.500 0.020 0.00000000 0.00000000 0.000 0.000 0.000 0 0 0 0 0 0.000 0.000 0.000 0.000 -6.217 -0.371 3.282 1.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 -6.257 -0.432 3.231 1.000 0.000 -2.740 1 1 0.000 0.000 0.000 0.000 1.000 1.000 0.000 0.000 0.000 0.000 1.000 1.000 0.000 0.000 0.000 1534336320.378 0.000 0.000 1534336320.377 1534336320.559 0 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0 0.000 0.000 0.000 0.000 0.000 0.000 -1.445 0.003 6.277 0.000 0.000 0.000 0.000 0.000 0.000 -1.524 6.275 6.263 1 0.000 0.000 0.000 0 0.000 0.000 0.000 0.000 -6.217 -0.371 3.282 1.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 -6.257 -0.432 3.231 1.000 0 0 0 0 0 0 0.000

## sudo gem install descriptive_statistics
require 'descriptive_statistics'

DEBUG_PRINT = false                 # default off
MAX_LATENCY_FOR_ERROR_STATE = 1.0  # 1 sec
MAX_DATA_LOSS_TIME_VSLAM = 0.3     # 300 ms
RECORD_PREFIX = "navi_log_input_data:"
FIELDS_NUM = 131 
INDEX_VSLAM_TS_0 = 64
INDEX_VSLAM_TS_1 = 67
INDEX_RECORD_TS = 68

# -------------------- main ---------------------- #
naviLogFile = ARGV[0]

if not File.exist?(naviLogFile)
  puts "#{naviLogFile} does not exist"
  exit 1
end

recLineNum = 0
vslam0_latency = []
vslam1_latency = []

File.readlines(naviLogFile).each do | line |
    next unless line.match(/^#{RECORD_PREFIX}/)
    fields = line.slice(RECORD_PREFIX.length, line.length).split(' ')
    next unless fields.count == FIELDS_NUM
    vslam0_ts, vslam1_ts, rec_ts = fields[INDEX_VSLAM_TS_0].to_f, fields[INDEX_VSLAM_TS_1].to_f, fields[INDEX_RECORD_TS].to_f
    la_0 = rec_ts - vslam0_ts
    la_1 = rec_ts - vslam1_ts
    puts "Processing record: [#{la_0}] [#{la_1}]" if DEBUG_PRINT
    recLineNum += 1
    vslam0_latency << la_0 if la_0 < MAX_LATENCY_FOR_ERROR_STATE 
    vslam1_latency << la_1 if la_1 < MAX_LATENCY_FOR_ERROR_STATE 
end

puts "Number of records: [#{recLineNum}, #{vslam0_latency.count}, #{vslam1_latency.count}]"

[ [vslam0_latency, "VSLAM_0 Latency"], [vslam1_latency, "VSLAM_1 Latency"] ].each do | stat, subject |
    next if stat.empty?
    puts subject 
    puts "  Max:                #{stat.sort.last.round(3)}"
    puts "  P95:                #{stat.percentile(95).round(3)}"
    puts "  P90:                #{stat.percentile(90).round(3)}"
    puts "  Average:            #{stat.mean.round(3)}"
    puts "  StandardDeviation:  #{stat.standard_deviation.round(3)}"
    puts "  %[<#{MAX_DATA_LOSS_TIME_VSLAM}]:            #{stat.percentile_rank(MAX_DATA_LOSS_TIME_VSLAM).round(3)}"
    puts "  Range:              #{stat.range.round(3)}"
end
