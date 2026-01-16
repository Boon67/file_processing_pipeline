# Troubleshooting: LLM Mapping Returns 0 Results

**Issue:** When generating LLM mappings, you see "Successfully generated 0 LLM-based field mappings" with "Skipped X invalid mappings (columns not in target schema)"

## Root Cause

The LLM is generating field mappings, but they are being rejected during validation because the suggested target columns don't exist in your `target_schemas` table definition.

## Solution Steps

### 1. Create Target Table Schema First

Before generating LLM mappings, you must define the target table structure:

1. Go to **📐 Target Table Designer** page
2. Click **➕ New Table**
3. Define your target table with all required columns:
   - Table name (e.g., `CLAIMS`, `MEMBERS`, `PROVIDERS`)
   - Add columns with names, data types, and descriptions
   - The more detailed your column descriptions, the better the LLM can map fields

### 2. Verify Target Table Exists

Check that your target table is properly defined:

```sql
SELECT table_name, column_name, data_type, description
FROM DB_INGEST_PIPELINE.SILVER.target_schemas
WHERE table_name = 'YOUR_TABLE_NAME'
  AND active = TRUE
ORDER BY schema_id;
```

### 3. Generate LLM Mappings

Once the target table schema is defined:

1. Go to **🗺️ Field Mapper** page
2. Select the **🧠 LLM Mapping** tab
3. Choose your LLM model (e.g., `CLAUDE-4-SONNET`)
4. Select the target table you just created
5. Click **Generate LLM Mappings**

### 4. Review and Approve Mappings

If mappings are generated successfully:

1. The approval dialog will appear automatically
2. Review each suggested mapping:
   - Source field → Target column
   - Confidence score
   - LLM reasoning
3. Check/uncheck mappings to approve/reject
4. Click **✅ Approve Selected** to save approved mappings

## Common Issues

### Issue: "No target tables found"
**Solution:** Create at least one target table in the Target Table Designer first.

### Issue: "Skipped X invalid mappings"
**Cause:** The LLM suggested columns that don't exist in your target schema.

**Solutions:**
- **Option A:** Add the missing columns to your target table schema
- **Option B:** Modify your target table to include the columns the LLM is suggesting
- **Option C:** Use a more specific prompt template that guides the LLM to only suggest existing columns

### Issue: "No source fields found in Bronze table"
**Solution:** Ensure you have ingested data into the Bronze layer first:
1. Upload files to Bronze stage
2. Run the Bronze ingestion task
3. Verify data exists: `SELECT * FROM DB_INGEST_PIPELINE.BRONZE.RAW_DATA_TABLE LIMIT 10;`

### Issue: LLM returns no mappings at all
**Possible causes:**
- Source and target field names are too different
- LLM model doesn't have enough context
- Prompt template needs refinement

**Solutions:**
- Add better descriptions to your target columns
- Try a different LLM model (Claude-4-Sonnet is recommended)
- Customize the prompt template in the **📋 Prompt Templates** tab

## Best Practices

1. **Define target schemas first** - Always create your target table structure before generating LLM mappings
2. **Use descriptive column names** - Clear, business-friendly names help the LLM make better suggestions
3. **Add column descriptions** - The more context you provide, the better the mappings
4. **Review all mappings** - Don't blindly approve all LLM suggestions; review each one
5. **Start with high-confidence mappings** - Approve mappings with confidence > 80% first
6. **Iterate** - Generate mappings, review, adjust your target schema, and regenerate if needed

## Example Workflow

```
1. Target Table Designer
   └─> Create table "CLAIMS" with columns:
       - CLAIM_ID (VARCHAR, "Unique claim identifier")
       - MEMBER_ID (VARCHAR, "Member/patient identifier")  
       - CLAIM_AMOUNT (NUMBER, "Total claim amount in dollars")
       - SERVICE_DATE (DATE, "Date service was provided")
       
2. Field Mapper → LLM Mapping
   └─> Select "CLAIMS" table
   └─> Generate mappings
   └─> LLM suggests:
       - claimId → CLAIM_ID (95% confidence)
       - memberId → MEMBER_ID (90% confidence)
       - totalAmount → CLAIM_AMOUNT (85% confidence)
       - serviceDate → SERVICE_DATE (92% confidence)
       
3. Review & Approve
   └─> Check all 4 mappings (all look good)
   └─> Click "Approve Selected"
   └─> Mappings are now active and ready for transformation
```

## Related Documentation

- [Target Table Designer Guide](../guides/target_table_designer.md)
- [Field Mapping Overview](../guides/field_mapping.md)
- [LLM Prompt Templates](../guides/llm_prompts.md)
