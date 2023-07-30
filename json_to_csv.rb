#!/usr/bin/env ruby
#
# Convert input JSON file into CSV and output it to standard output.
# Specify a JSON file obtained by `aws cloudwatch get-metric-data` as the first argument.
#

require 'csv'
require 'json'
require 'set'
require 'time'

def format_time_string(time_string)
  # Set "%F" if only the date part of a Time is needed.
  Time.parse(time_string).getlocal.strftime("%F %T")
end

results = JSON.parse(File.read(ARGV[0]))["MetricDataResults"]

time_set = Set.new
results.each do |result|
  times = result["Timestamps"].map { |t| format_time_string(t) }
  time_set += Set.new(times)
end
time_header = time_set.to_a.sort!

rows = []
rows << ["Time"].concat(time_header)
results.each do |result|
  label = result["Label"]
  unless result["StatusCode"] == "Complete"
    raise StandardError.new("StatusCode is not Complete. Label: \"#{label}\"")
  end
  times = result["Timestamps"].reverse!.map { |t| format_time_string(t) }
  values = result["Values"].reverse!
  values_by_time = Hash[*[times, values].transpose.flatten]
  complemented = {}
  time_header.each { |time| complemented[time] = values_by_time[time]}
  rows << [label].concat(complemented.values)
end

# Transpose data to align time series from top to bottom.
# To align them left to right, remove this line.
rows = rows.transpose

CSV { |csv| rows.each { |row| csv << row }}
