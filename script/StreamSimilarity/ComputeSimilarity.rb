#!/usr/bin/env ruby

## Description: Script to compute similarity of two record based files.
#               The file names are hard coded here. And the record pattern of each file
#               needs to be carefully matching the provided preprocess_*_line handlers.
#               File truth.txt, providing ground truth records
#               File observation.txt, providing measured records
#
## Usage:       ruby ComputeSimilarity.rb

require 'matrix'

TruthFilename = 'truth.txt'
ObservationFilename = 'observation.txt'
ProgressDotsPerLine = 72

# Symbol -> Token 1x1 mapping
$symTable = {}

# Tokens array for Truth data stream
$truthTokens = []

# Tokens array for truncated Obversvation stream
$observationTokens = []

## Process a raw line and return the synthesized symbol of the truth record
# Sample: 
#   "5352 Recv    15:03:55.362.0  0x000001ae  DataFrame    StdFrame   0x08    1a3a000000000000"
#   "9983\tRecv\t15:04:10.061.0\t0x1824f401\tDataFrame\t ExtFrame\t0x08\t004a004b004a0000 \r\n"
# @param  String
# @return String or Nil
def preprocess_truth_line(text)
  matches = text.match(/^\d+[\t|\s]+Recv[\t|\s]+.{14}[\t|\s]+0x([\d|a-f]+)[\t|\s]+\w+[\t|\s]+\w+[\t|\s]+0x[\d|a-f]+[\t|\s]+([\d|a-f]+)/)
  return nil if matches.nil?
  frame_id, frame_data = matches[1], matches[2]
  frame_id.upcase.sub(/^[0:]*/,"") + '#' + frame_data.upcase
end

## Process a raw line and return the synthesized symbol of the observation record
# Sample:
#   "(2017-12-26 15:04:10.818578) can0 18A#003A000000000000"
#   "(2017-12-26 15:04:05.204456) can0 28A#0284004900110000\n"
# @param String
# @return String or Nil
def preprocess_obvervation_line(text)
  matches = text.match(/can\d\s+([\d|A-F]+\#[\d|A-F]+)\n?$/)
  return nil if matches.nil?
  matches[1]
end

## Create a symbol -> token 1x1 mapping if it is a new symbol
#  and prime the corresponding token into given tokens stream.
# @param  String
# @param  Proc
# @param  [Integer]
# @return Integer or Nil
#
# $symTable will be modifed. {String => Integer}
# $truthTokens may be modified, [Integer]
# $observationTokens may be modified, [Integer]
def generate_symTable_and_tokens(symbol, preprocessor, target_stream)
  record = send(preprocessor, symbol)
  return nil if record.nil?
  if $symTable.has_key?(record)
    token_id = $symTable[record]
  else
    token_id = $symTable.size
    $symTable[record] = token_id
  end
  target_stream << token_id
  token_id
end

## Compute the smallest edit distance (Levenshtein Distance) of the two token streams
# @param  [Integer]
# @param  [Integer]
# @return Integer
#
# Dynamic programming algorithm for computing the minimal steps to make eval_stream
# equal to ref_stream.  edit action includes: Insert, Replace, Delete, a token.
#   M = eval_stream.length, for simple, M[j] = eval_stream[j], j = [0,M]
#   N = ref_stream.length,  for simple, N[i] = ref_stream[i],  i = [0,N]
#   Array = N * M, for simple, A[i,j] = the minimal steps for editing M[0]...M[j] to N[0]...N[i]
#   Set A[i,0] = i, where i in [0, N)
#                   which means an empty M can become N[0]...N[i] by adding i tokens
#   Set A[0,j] = j, where j in [0, M),
#                   which means a non-empty M can become empty N by deleting j tokens
#   A[i,j] = minimal of cases:
#            (1)  A[i-1,j-1] + Cost of Replace M[j] with N[i]
#            (2)  A[i,j-1] + Cost of Insert N[i] immediately after M[j-1]
#            (3)  A[i-1,j] + Cost of Delete M[j]
#   Cost of:
#       (1) Replace M[j] with N[i] = 0,  if N[i] == M[j]
#                                    1,  otherwise
#       (2) Insert N[i] immediately after M[j-1] = 1
#       (3) Delete M[j] = 1
#   Result = A[N,M]
def compute_smallest_edit_distance(eval_stream, ref_stream)
  m_sz, n_sz = eval_stream.size, ref_stream.size
  arr = Matrix.build(n_sz+1, m_sz+1) do |row, col|
    if row == 0
      col
    elsif col == 0
      row
    else
      0
    end
  end.to_a
  puts "[INFO] DP Matrix generated: #{arr.size} x #{arr.first.size}"
  progress_dots = 0
  puts "[INFO] Start computing"
  for j in 1..m_sz
    for i in 1..n_sz
      replace_cost = arr[i-1][j-1] + (eval_stream[j] == ref_stream[i] ? 0 : 1)
      insert_cost = arr[i][j-1] + 1
      delete_cost = arr[i-1][j] + 1
      arr[i][j] = [replace_cost, insert_cost, delete_cost].min
    end
    print "."
    progress_dots += 1
    print " #{(progress_dots.to_f/m_sz * 100).round(3)}%\n" if (0 == progress_dots % ProgressDotsPerLine)
  end
  print "\n"
  arr[n_sz][m_sz]
end

## Open the two input files, read in by line, and compute their similiarity
# @param  String
# @param  String
# @return Float
def perform(truth_fn, observation_fn)
  # Preprocess Truth file
  line_num = 0
  File.readlines(truth_fn).each do |text|
    line_num += 1
    if generate_symTable_and_tokens(text, :preprocess_truth_line, $truthTokens).nil?
      puts "[INFO] Ignore #{truth_fn}:#{line_num} => #{text}"
    end
  end
  # Preprocess Obversation file
  line_num = 0
  File.readlines(observation_fn).each do |text|
    line_num += 1
    if generate_symTable_and_tokens(text, :preprocess_obvervation_line, $observationTokens).nil?
      puts "[INFO] Ignore #{observation_fn}:#{line_num} => #{text}"
    end
  end
  puts "[INFO] >>> Number of Symbols: #{$symTable.size}"
  puts "[INFO] >>> Number of Turth Stream Tokens: #{$truthTokens.size}"
  puts "[INFO] >>> Number of Obversation Stream Tokens: #{$observationTokens.size}"
  # Compute similarity of the obversation stream against to truth stream
  if 0 == $truthTokens.size
    puts "[ERROR] Can not compute similarity. Empty truth values."
    exit 1
  end
  distance = compute_smallest_edit_distance($observationTokens, $truthTokens)
  puts "[INFO] >>> Minimal Edit Distance = #{distance}"
  ($truthTokens.size - distance).to_f / $truthTokens.size
end

# -------------------- main ---------------------- #
if not File.exist?(TruthFilename)
  puts "#{TruthFilename} does not exist"
  exit 1
end

if not File.exist?(ObservationFilename)
  puts "#{ObservationFilename} does not exist"
  exit 1
end

$similarity = perform(TruthFilename, ObservationFilename)
puts "Similiarity: #{$similarity}"