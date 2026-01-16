# Snowflake Performance Optimization

## Important Note: No Traditional Indexes

**Snowflake does NOT support traditional database indexes** like other RDBMS systems (Oracle, SQL Server, PostgreSQL, etc.).

## How Snowflake Optimizes Performance

### 1. Micro-Partitions

Snowflake automatically organizes data into **micro-partitions** (50-500 MB compressed):
- Automatic partitioning based on ingestion order
- Metadata tracks min/max values for each column
- Query optimizer uses metadata to skip irrelevant micro-partitions (pruning)

### 2. Clustering Keys (Optional)

For very large tables (typically >1TB), you can define **clustering keys**:

```sql
-- Define clustering on frequently filtered columns
ALTER TABLE RAW_DATA_TABLE CLUSTER BY (TPA, LOAD_TIMESTAMP);
```

**When to use clustering:**
- ✅ Tables larger than 1TB
- ✅ Queries frequently filter on specific columns
- ✅ Query performance is suboptimal

**When NOT to use clustering:**
- ❌ Small to medium tables (<100GB)
- ❌ Tables with frequent inserts (clustering maintenance overhead)
- ❌ Columns with high cardinality and random access patterns

### 3. Search Optimization Service

For point lookups on large tables:

```sql
-- Enable search optimization (additional cost)
ALTER TABLE RAW_DATA_TABLE ADD SEARCH OPTIMIZATION;
```

**Use cases:**
- Point lookups (WHERE column = 'value')
- Substring searches (WHERE column LIKE '%value%')
- Selective queries on large tables

**Cost consideration:** Additional storage and compute costs

## Performance Best Practices

### 1. Query Design

**Good:**
```sql
-- Filter early, prune partitions
SELECT * FROM RAW_DATA_TABLE
WHERE TPA = 'provider_a'
AND LOAD_TIMESTAMP >= '2026-01-01';
```

**Bad:**
```sql
-- Full table scan, no pruning
SELECT * FROM RAW_DATA_TABLE
WHERE UPPER(TPA) = 'PROVIDER_A';  -- Function prevents pruning
```

### 2. Column Selection

**Good:**
```sql
-- Select only needed columns
SELECT FILE_NAME, TPA, LOAD_TIMESTAMP
FROM RAW_DATA_TABLE;
```

**Bad:**
```sql
-- SELECT * reads all columns (including large VARIANT)
SELECT * FROM RAW_DATA_TABLE;
```

### 3. Partitioning Awareness

**Good:**
```sql
-- Filters on partition-friendly columns
WHERE LOAD_TIMESTAMP BETWEEN '2026-01-01' AND '2026-01-31'
AND TPA IN ('provider_a', 'provider_b');
```

**Bad:**
```sql
-- Functions prevent partition pruning
WHERE DATE_TRUNC('month', LOAD_TIMESTAMP) = '2026-01-01'
OR SUBSTRING(TPA, 1, 8) = 'provider';
```

### 4. Result Set Size

**Good:**
```sql
-- Limit results for UI/exploration
SELECT * FROM RAW_DATA_TABLE
WHERE TPA = 'provider_a'
LIMIT 1000;
```

**Bad:**
```sql
-- Returning millions of rows to client
SELECT * FROM RAW_DATA_TABLE;  -- No LIMIT
```

## Our Implementation

### Bronze Layer

**RAW_DATA_TABLE:**
- No clustering needed (moderate size expected)
- Queries filtered by TPA and LOAD_TIMESTAMP
- Automatic micro-partition pruning sufficient

**file_processing_queue:**
- Small table, no optimization needed
- Primary key provides fast lookups

**TPA_MASTER:**
- Very small table (<100 rows expected)
- No optimization needed

### Silver Layer

**field_mappings:**
- Small table (hundreds to thousands of rows)
- No optimization needed
- Primary key on mapping_id

**transformation_rules:**
- Small table (hundreds of rules)
- No optimization needed
- Primary key on rule_id

**Target tables (CLAIMS, etc.):**
- May benefit from clustering if >1TB
- Monitor query performance first
- Add clustering only if needed

## Monitoring Performance

### 1. Query Profile

Use Snowflake's Query Profile to analyze:
- Partition pruning effectiveness
- Bytes scanned vs. bytes returned
- Execution time breakdown

### 2. Query History

```sql
-- Find slow queries
SELECT 
    query_text,
    execution_time,
    bytes_scanned,
    rows_produced
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE execution_time > 10000  -- > 10 seconds
ORDER BY execution_time DESC
LIMIT 10;
```

### 3. Table Statistics

```sql
-- Check table size and row count
SELECT 
    table_name,
    row_count,
    bytes,
    ROUND(bytes / 1024 / 1024 / 1024, 2) as size_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE table_schema = 'BRONZE'
ORDER BY bytes DESC;
```

## When to Optimize

### Signals You Need Optimization

1. **Queries taking >30 seconds** on filtered data
2. **Full table scans** on large tables (>100GB)
3. **High bytes scanned** relative to bytes returned
4. **Frequent queries** on same columns

### Optimization Steps

1. **Analyze Query Profile** - Identify bottlenecks
2. **Check Partition Pruning** - Ensure filters work
3. **Consider Clustering** - For very large tables
4. **Test Impact** - Measure before/after performance
5. **Monitor Costs** - Clustering has maintenance overhead

## Cost Considerations

### Clustering Costs

- **Storage**: Slightly higher due to metadata
- **Compute**: Automatic reclustering consumes credits
- **Benefit**: Faster queries, lower query costs

### Search Optimization Costs

- **Storage**: Additional search access paths
- **Compute**: Building and maintaining search structures
- **Benefit**: Much faster point lookups

### Trade-offs

For our pipeline:
- **Small to medium data**: No optimization needed
- **Large data (>1TB)**: Consider clustering on TPA + LOAD_TIMESTAMP
- **Point lookups**: Search optimization only if needed

## Summary

✅ **Do:**
- Let Snowflake handle optimization automatically
- Write efficient queries (filter early, select specific columns)
- Monitor query performance
- Add clustering only for very large tables (>1TB)

❌ **Don't:**
- Try to create traditional indexes (not supported)
- Over-optimize small tables
- Add clustering without measuring impact
- Use functions in WHERE clauses that prevent pruning

## References

- [Snowflake Micro-Partitions](https://docs.snowflake.com/en/user-guide/tables-clustering-micropartitions)
- [Clustering Keys](https://docs.snowflake.com/en/user-guide/tables-clustering-keys)
- [Search Optimization](https://docs.snowflake.com/en/user-guide/search-optimization-service)
- [Query Performance](https://docs.snowflake.com/en/user-guide/ui-snowsight-query-profile)

---

**Key Takeaway**: Snowflake's automatic optimization is sufficient for most use cases. Only consider clustering or search optimization for very large tables with proven performance issues.
