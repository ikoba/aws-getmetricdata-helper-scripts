# AWS GetMetricData Helper Scripts

This is a collection of Ruby scripts that helps to get metric data and convert its result.

## How to get metric data

### 1. List available metrics in your environment

```bash
aws cloudwatch list-metrics | tee metrics.json
```

### 2. Define metrics and period

Modify constants `TARGET_METRICS` and `PERIOD` in `create_query.rb` depending on your needs.

### 3. Create a query

```bash
./create_query.rb metrics.json | tee query.json
```

### 4. Execute get-metric-data

Example

```bash
aws cloudwatch get-metric-data \
  --metric-data-queries file://query.json \
  --start-time "2023-06-01T00:00:00+0900" \
  --end-time "2023-07-01T00:00:00+0900" \
  | tee result.json
```

### 5. Convert JSON to CSV

To convert JSON metric data into CSV format, execute the following script.

```bash
./json_to_csv result.json | tee result.csv
```
