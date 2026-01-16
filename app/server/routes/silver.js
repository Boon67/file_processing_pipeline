const express = require('express');
const router = express.Router();
const { getSnowflakeConnection } = require('../utils/snowflake');

/**
 * GET /api/silver/mappings
 * Get field mappings
 */
router.get('/mappings', async (req, res, next) => {
  try {
    const { tpa, target_table, active_only = 'true' } = req.query;
    const snowflake = getSnowflakeConnection();
    
    let query = `
      SELECT 
        mapping_id,
        tpa,
        source_field,
        target_table,
        target_field,
        transformation_logic,
        data_type,
        is_required,
        default_value,
        validation_rule,
        priority,
        active,
        created_timestamp,
        updated_timestamp
      FROM silver.field_mappings
      WHERE 1=1
    `;
    
    const binds = [];
    
    if (tpa) {
      query += ` AND tpa = ?`;
      binds.push(tpa);
    }
    
    if (target_table) {
      query += ` AND target_table = ?`;
      binds.push(target_table);
    }
    
    if (active_only === 'true') {
      query += ` AND active = TRUE`;
    }
    
    query += ` ORDER BY target_table, priority, source_field`;
    
    const mappings = await snowflake.query(query, binds);
    
    res.json({
      mappings: mappings
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/silver/mappings
 * Create field mapping
 */
router.post('/mappings', async (req, res, next) => {
  try {
    const {
      tpa,
      source_field,
      target_table,
      target_field,
      transformation_logic,
      data_type,
      is_required,
      default_value,
      validation_rule,
      priority
    } = req.body;
    
    if (!tpa || !source_field || !target_table || !target_field) {
      return res.status(400).json({ 
        error: 'TPA, source_field, target_table, and target_field are required' 
      });
    }
    
    const snowflake = getSnowflakeConnection();
    
    const result = await snowflake.execute(`
      INSERT INTO silver.field_mappings (
        tpa, source_field, target_table, target_field,
        transformation_logic, data_type, is_required,
        default_value, validation_rule, priority
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      tpa, source_field, target_table, target_field,
      transformation_logic, data_type, is_required || false,
      default_value, validation_rule, priority || 100
    ]);
    
    res.status(201).json({
      message: 'Mapping created successfully',
      mapping_id: result.insertId
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PUT /api/silver/mappings/:id
 * Update field mapping
 */
router.put('/mappings/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const updates = req.body;
    
    const snowflake = getSnowflakeConnection();
    
    const allowedFields = [
      'transformation_logic', 'data_type', 'is_required',
      'default_value', 'validation_rule', 'priority', 'active'
    ];
    
    const setClauses = [];
    const binds = [];
    
    for (const [key, value] of Object.entries(updates)) {
      if (allowedFields.includes(key)) {
        setClauses.push(`${key} = ?`);
        binds.push(value);
      }
    }
    
    if (setClauses.length === 0) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }
    
    setClauses.push('updated_timestamp = CURRENT_TIMESTAMP()');
    binds.push(id);
    
    await snowflake.execute(`
      UPDATE silver.field_mappings
      SET ${setClauses.join(', ')}
      WHERE mapping_id = ?
    `, binds);
    
    res.json({
      message: 'Mapping updated successfully'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /api/silver/mappings/:id
 * Delete field mapping (soft delete)
 */
router.delete('/mappings/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const snowflake = getSnowflakeConnection();
    
    await snowflake.execute(`
      UPDATE silver.field_mappings
      SET active = FALSE, updated_timestamp = CURRENT_TIMESTAMP()
      WHERE mapping_id = ?
    `, [id]);
    
    res.json({
      message: 'Mapping deleted successfully'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/silver/rules
 * Get transformation rules
 */
router.get('/rules', async (req, res, next) => {
  try {
    const { tpa, rule_type, active_only = 'true' } = req.query;
    const snowflake = getSnowflakeConnection();
    
    let query = `
      SELECT 
        rule_id,
        tpa,
        rule_name,
        rule_type,
        rule_category,
        target_table,
        target_field,
        rule_logic,
        error_handling,
        severity,
        active,
        created_timestamp,
        updated_timestamp
      FROM silver.transformation_rules
      WHERE 1=1
    `;
    
    const binds = [];
    
    if (tpa) {
      query += ` AND tpa = ?`;
      binds.push(tpa);
    }
    
    if (rule_type) {
      query += ` AND rule_type = ?`;
      binds.push(rule_type);
    }
    
    if (active_only === 'true') {
      query += ` AND active = TRUE`;
    }
    
    query += ` ORDER BY rule_category, rule_name`;
    
    const rules = await snowflake.query(query, binds);
    
    res.json({
      rules: rules
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/silver/rules
 * Create transformation rule
 */
router.post('/rules', async (req, res, next) => {
  try {
    const {
      tpa,
      rule_name,
      rule_type,
      rule_category,
      target_table,
      target_field,
      rule_logic,
      error_handling,
      severity
    } = req.body;
    
    if (!tpa || !rule_name || !rule_type || !rule_logic) {
      return res.status(400).json({ 
        error: 'TPA, rule_name, rule_type, and rule_logic are required' 
      });
    }
    
    const snowflake = getSnowflakeConnection();
    
    const result = await snowflake.execute(`
      INSERT INTO silver.transformation_rules (
        tpa, rule_name, rule_type, rule_category,
        target_table, target_field, rule_logic,
        error_handling, severity
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      tpa, rule_name, rule_type, rule_category,
      target_table, target_field, rule_logic,
      error_handling || 'LOG', severity || 'WARNING'
    ]);
    
    res.status(201).json({
      message: 'Rule created successfully',
      rule_id: result.insertId
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/silver/transform
 * Execute transformation
 */
router.post('/transform', async (req, res, next) => {
  try {
    const { tpa, target_table } = req.body;
    
    if (!tpa) {
      return res.status(400).json({ error: 'TPA is required' });
    }
    
    const snowflake = getSnowflakeConnection();
    
    // Call transformation procedure
    await snowflake.execute(`
      CALL silver.transform_data(?, ?)
    `, [tpa, target_table || null]);
    
    res.json({
      message: 'Transformation started successfully',
      tpa: tpa,
      target_table: target_table
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/silver/data
 * Query transformed data
 */
router.get('/data', async (req, res, next) => {
  try {
    const { table, limit = 100, offset = 0 } = req.query;
    
    if (!table) {
      return res.status(400).json({ error: 'Table name is required' });
    }
    
    const snowflake = getSnowflakeConnection();
    
    // Validate table name to prevent SQL injection
    const validTables = ['claims', 'members', 'providers', 'pharmacy'];
    if (!validTables.includes(table.toLowerCase())) {
      return res.status(400).json({ error: 'Invalid table name' });
    }
    
    const data = await snowflake.query(`
      SELECT *
      FROM silver.${table}
      ORDER BY created_timestamp DESC
      LIMIT ? OFFSET ?
    `, [parseInt(limit), parseInt(offset)]);
    
    const count = await snowflake.query(`
      SELECT COUNT(*) as total
      FROM silver.${table}
    `);
    
    res.json({
      data: data,
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        total: count[0].TOTAL
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/silver/quality
 * Get data quality metrics
 */
router.get('/quality', async (req, res, next) => {
  try {
    const { tpa } = req.query;
    const snowflake = getSnowflakeConnection();
    
    let query = `
      SELECT 
        metric_name,
        metric_value,
        target_value,
        status,
        measured_timestamp
      FROM silver.data_quality_metrics
      WHERE 1=1
    `;
    
    const binds = [];
    
    if (tpa) {
      query += ` AND tpa = ?`;
      binds.push(tpa);
    }
    
    query += ` ORDER BY measured_timestamp DESC LIMIT 100`;
    
    const metrics = await snowflake.query(query, binds);
    
    res.json({
      metrics: metrics
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/silver/summary
 * Get Silver layer summary statistics
 */
router.get('/summary', async (req, res, next) => {
  try {
    const snowflake = getSnowflakeConnection();
    
    const mappings = await snowflake.query(`
      SELECT 
        COUNT(*) as total_mappings,
        COUNT(DISTINCT tpa) as total_tpas,
        COUNT(DISTINCT target_table) as total_tables,
        SUM(CASE WHEN active = TRUE THEN 1 ELSE 0 END) as active_mappings
      FROM silver.field_mappings
    `);
    
    const rules = await snowflake.query(`
      SELECT 
        COUNT(*) as total_rules,
        COUNT(DISTINCT rule_type) as rule_types,
        SUM(CASE WHEN active = TRUE THEN 1 ELSE 0 END) as active_rules
      FROM silver.transformation_rules
    `);
    
    res.json({
      mappings: mappings[0],
      rules: rules[0]
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
