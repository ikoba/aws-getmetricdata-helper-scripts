#!/usr/bin/env ruby
#
# Output JSON query to standard output.
# Specify a JSON file obtained by `aws cloudwatch list-metrics` as the first argument.
#
# The created query can be used as follows.
#
# aws cloudwatch get-metric-data \
#   --metric-data-queries file://query.json \
#   --start-time "2023-06-01T00:00:00+0900" \
#   --end-time "2023-07-01T00:00:00+0900" \
#   | tee result.json
#
# About get-metric-data command, please see below.
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/cloudwatch/get-metric-data.html
#

require 'csv'
require 'digest'
require 'json'

# The granularity, in seconds, of the returned data points.
PERIOD = 3600 * 24 # 1 day

# Define metrics you want.
# { Namespace => { MetricName => [Stats] }}
TARGET_METRICS = {
  "AWS/DynamoDB" => {
    "ConsumedReadCapacityUnits" => ["Sum"],
    "ConsumedWriteCapacityUnits" => ["Sum"],
  },
  "AWS/ECS" => {
    "CPUUtilization" => ["Minimum", "Maximum", "Average"],
    "MemoryUtilization" => ["Minimum", "Maximum", "Average"],
  },
  "AWS/Firehose" => {
    "DataReadFromKinesisStream.Bytes" => ["Sum"],
    "SucceedConversion.Bytes" => ["Sum"]
  },
  "AWS/Glue" => {
    "ResourceUsage" => ["Minimum", "Maximum", "Average"],
  },
  "AWS/IoT" => {
    "Connect.Success" => ["Sum"],
    "PublishIn.Success" => ["Sum"],
    "PublishOut.Success" => ["Sum"],
  },
  "AWS/Kinesis" => {
    "IncomingBytes" => ["Sum"],
  },
  "AWS/MWAA" => {
    "CPUUtilization" => ["Minimum", "Maximum", "Average"],
    "MemoryUtilization" => ["Minimum", "Maximum", "Average"],
  },
  "AWS/RDS" => {
    "CPUUtilization" => ["Minimum", "Maximum", "Average"],
  },
  "AWS/Redshift" => {
    "CPUUtilization" => ["Minimum", "Maximum", "Average"],
  },
  "ECS/ContainerInsights" => {
    "CpuReserved" => ["Average"],
    "MemoryReserved" => ["Average"],
    "RunningTaskCount" => ["Average"],
  },
}.freeze

def target_metric?(metric)
  !TARGET_METRICS[metric["Namespace"]]&.[](metric["MetricName"]).nil?
end

def deep_dup(obj)
  Marshal.load(Marshal.dump(obj))
end

def create_metric_query(base_query, metric, stat)
  query = deep_dup(base_query)
  query["MetricStat"]["Stat"] = stat
  # The valid characters are letters, numbers, and underscore.
  # The first character must be a lowercase letter.
  query["Id"] = "h" + Digest::MD5.hexdigest([metric, stat].to_json)
  query
end

def create_query(metrics)
  metrics.each_with_object([]) do |metric, queries|
    base_query = {}
    base_query["MetricStat"] = {}
    base_query["MetricStat"]["Metric"] = metric
    base_query["MetricStat"]["Period"] = PERIOD

    stats = TARGET_METRICS[metric["Namespace"]][metric["MetricName"]]
    stats.each do |stat|
      queries << create_metric_query(base_query, metric, stat)
    end
  end
end

def sort_query(queries)
  queries.sort do |a, b|
    namespace_cmp = a["MetricStat"]["Metric"]["Namespace"] <=> b["MetricStat"]["Metric"]["Namespace"]
    next namespace_cmp unless namespace_cmp == 0

    metric_cmp = a["MetricStat"]["Metric"]["MetricName"] <=> b["MetricStat"]["Metric"]["MetricName"]
    next metric_cmp unless metric_cmp == 0

    dimensions_cmp = a["MetricStat"]["Metric"]["Dimensions"].to_json <=> b["MetricStat"]["Metric"]["Dimensions"].to_json
    next dimensions_cmp unless dimensions_cmp == 0

    a["MetricStat"]["Stat"] <=> b["MetricStat"]["Stat"]
  end
end

metrics_list = File.read(ARGV[0])
available_metrics = JSON.parse(metrics_list)["Metrics"]
target_metrics = available_metrics.select { |t| target_metric?(t) }
query = create_query(target_metrics)
query = sort_query(query)

puts JSON.dump(query)
