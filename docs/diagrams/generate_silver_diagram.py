#!/usr/bin/env python3
"""
Generate Silver Layer Workflow Diagram
Professional visualization of the Silver data transformation pipeline
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import matplotlib.lines as mlines

# Set up the figure with high DPI for professional quality
fig, ax = plt.subplots(figsize=(20, 24))
ax.set_xlim(0, 20)
ax.set_ylim(0, 24)
ax.axis('off')

# Define color scheme (professional, accessible colors)
colors = {
    'user': '#E8EAF6',           # Light indigo
    'streamlit': '#B3E5FC',      # Light blue
    'stage': '#FFF9C4',          # Light yellow
    'task': '#C8E6C9',           # Light green
    'procedure': '#BBDEFB',      # Light blue
    'table': '#F8BBD0',          # Light pink
    'metadata': '#E1BEE7',       # Light purple
    'mapping': '#FFCCBC',        # Light orange
    'rules': '#DCEDC8',          # Light lime
    'quality': '#B2DFDB',        # Light teal
}

# Helper function to create boxes
def create_box(ax, x, y, width, height, text, color, style='round', alpha=0.8):
    if style == 'round':
        box = FancyBboxPatch((x, y), width, height,
                            boxstyle="round,pad=0.1",
                            facecolor=color, edgecolor='#424242',
                            linewidth=2, alpha=alpha)
    else:
        box = FancyBboxPatch((x, y), width, height,
                            facecolor=color, edgecolor='#424242',
                            linewidth=2, alpha=alpha)
    ax.add_patch(box)
    
    # Add text
    lines = text.split('\n')
    y_offset = y + height/2 + (len(lines)-1)*0.15
    for line in lines:
        ax.text(x + width/2, y_offset, line,
               ha='center', va='center', fontsize=9, weight='bold')
        y_offset -= 0.3

# Helper function to create arrows
def create_arrow(ax, x1, y1, x2, y2, label='', color='#424242', style='->'):
    arrow = FancyArrowPatch((x1, y1), (x2, y2),
                           arrowstyle=style, color=color,
                           linewidth=2, mutation_scale=20)
    ax.add_patch(arrow)
    
    if label:
        mid_x, mid_y = (x1 + x2) / 2, (y1 + y2) / 2
        ax.text(mid_x + 0.3, mid_y, label,
               fontsize=7, style='italic',
               bbox=dict(boxstyle='round,pad=0.3', facecolor='white', alpha=0.8))

# Title
ax.text(10, 23.5, 'Snowflake Silver Layer Data Transformation Pipeline',
       ha='center', va='top', fontsize=20, weight='bold')
ax.text(10, 23, 'Intelligent Data Transformation with ML/LLM Field Mapping & Rules Engine',
       ha='center', va='top', fontsize=11, style='italic', color='#666')

# ============================================================================
# LEFT SIDE: Key Features
# ============================================================================
create_box(ax, 0.5, 18, 3, 4.5, '', colors['user'])
ax.text(2, 22.2, 'Key Features', ha='center', va='top', fontsize=11, weight='bold')

features = [
    '• Dynamic Schema',
    '  Metadata-driven tables',
    '',
    '• 3 Mapping Methods',
    '  Manual, ML, LLM',
    '',
    '• 4 Rule Types',
    '  Quality, Business,',
    '  Standardization, Dedup',
    '',
    '• Data Quality',
    '  Metrics & Quarantine',
    '',
    '• Incremental Load',
    '  Watermark-based',
]
y_pos = 21.5
for feature in features:
    ax.text(0.7, y_pos, feature, ha='left', va='top', fontsize=8)
    y_pos -= 0.25

# ============================================================================
# RIGHT SIDE: Component Types Legend
# ============================================================================
create_box(ax, 16.5, 18, 3, 4.5, '', colors['user'])
ax.text(18, 22.2, 'Component Types', ha='center', va='top', fontsize=11, weight='bold')

legend_items = [
    ('User Interface', colors['user']),
    ('Streamlit App', colors['streamlit']),
    ('Snowflake Stage', colors['stage']),
    ('Snowflake Task', colors['task']),
    ('Stored Procedure', colors['procedure']),
    ('Metadata Table', colors['metadata']),
    ('Data Table', colors['table']),
    ('Mapping Engine', colors['mapping']),
    ('Rules Engine', colors['rules']),
    ('Quality Check', colors['quality']),
]

y_pos = 21.5
for label, color in legend_items:
    # Small color box
    box = FancyBboxPatch((16.7, y_pos-0.15), 0.3, 0.25,
                         boxstyle="round,pad=0.02",
                         facecolor=color, edgecolor='#424242', linewidth=1)
    ax.add_patch(box)
    ax.text(17.2, y_pos, label, ha='left', va='center', fontsize=8)
    y_pos -= 0.35

# ============================================================================
# TOP: User & Streamlit Interface
# ============================================================================

# User
create_box(ax, 1, 20.5, 2, 1.2, 'User\nData Engineer\nData Analyst', colors['user'])

# Streamlit in Snowflake
create_box(ax, 4.5, 19.5, 3.5, 2.5, '', colors['streamlit'])
ax.text(6.25, 21.7, 'Streamlit in Snowflake', ha='center', fontsize=10, weight='bold')
ax.text(6.25, 21.3, 'Silver Transformation Manager', ha='center', fontsize=8)
streamlit_features = [
    '• Schema Designer',
    '• Field Mapper (Manual/ML/LLM)',
    '• Rules Engine Manager',
    '• Transformation Monitor',
    '• Data Quality Dashboard',
    '• Task Management',
]
y_pos = 20.8
for feature in streamlit_features:
    ax.text(4.7, y_pos, feature, ha='left', fontsize=7)
    y_pos -= 0.25

# Arrow from User to Streamlit
create_arrow(ax, 3, 21, 4.5, 21, 'Access Web UI')

# ============================================================================
# BRONZE DATA INPUT
# ============================================================================

# Bronze RAW_DATA_TABLE
create_box(ax, 1, 17, 3, 1.2, 'BRONZE.RAW_DATA_TABLE\nVariant data from ingestion\nSource: Bronze Layer',
          colors['table'])

# Arrow from Streamlit to Bronze
create_arrow(ax, 6.25, 19.5, 2.5, 18.2, 'Monitor\nSource')

# ============================================================================
# METADATA LAYER (Left side)
# ============================================================================

ax.text(1.5, 15.8, 'Metadata Layer', ha='left', fontsize=11, weight='bold',
       bbox=dict(boxstyle='round,pad=0.3', facecolor='#E1BEE7', alpha=0.5))

# Target Schemas metadata
create_box(ax, 0.5, 14, 2.5, 1.2, 'TARGET_SCHEMAS\nTable definitions\nColumn metadata',
          colors['metadata'])

# Field Mappings metadata
create_box(ax, 0.5, 12.3, 2.5, 1.2, 'FIELD_MAPPINGS\nBronze → Silver maps\n3 methods: Manual/ML/LLM',
          colors['metadata'])

# Transformation Rules metadata
create_box(ax, 0.5, 10.6, 2.5, 1.2, 'TRANSFORMATION_RULES\n4 types: DQ/BL/STD/DD\nPriority-based execution',
          colors['metadata'])

# ============================================================================
# SILVER STAGES
# ============================================================================

# Silver Stage
create_box(ax, 9, 17, 3, 1.2, '@SILVER_STAGE\nTransformed data zone\nSILVER Schema',
          colors['stage'])

# Arrow from Bronze to Silver Stage
create_arrow(ax, 4, 17.6, 9, 17.6, 'Read')

# ============================================================================
# TASK 1: BRONZE COMPLETION SENSOR
# ============================================================================

create_box(ax, 5, 15.5, 5, 1.2, 'Task 1: BRONZE_COMPLETION_SENSOR\nSchedule: Every 5 Minutes\nDetect new Bronze data',
          colors['task'])

# Arrow from Bronze to Task 1
create_arrow(ax, 2.5, 17, 7.5, 16.7, 'Trigger')

# ============================================================================
# TASK 2: SILVER DISCOVERY
# ============================================================================

create_box(ax, 5, 13.8, 5, 1.2, 'Task 2: SILVER_DISCOVERY_TASK\nAfter: Task 1 Completes\nDiscover unmapped fields',
          colors['task'])

# Arrow from Task 1 to Task 2
create_arrow(ax, 7.5, 15.5, 7.5, 15, 'Execute')

# discover_bronze_schema Procedure
create_box(ax, 11, 13.8, 3, 1.2, 'discover_bronze_schema()\nAnalyze VARIANT fields\nSuggest target schema',
          colors['procedure'])

# Arrow from Task 2 to Procedure
create_arrow(ax, 10, 14.4, 11, 14.4, 'Call')

# Arrow from Procedure to Metadata
create_arrow(ax, 11, 14.4, 3, 14.6, 'Update\nSchemas', color='#7B1FA2')

# ============================================================================
# FIELD MAPPING LAYER
# ============================================================================

ax.text(11.5, 12.3, 'Field Mapping Engine', ha='center', fontsize=11, weight='bold',
       bbox=dict(boxstyle='round,pad=0.3', facecolor=colors['mapping'], alpha=0.7))

# Manual Mapping
create_box(ax, 10.5, 10.8, 2, 0.8, 'Manual Mapping\nCSV Upload\nConfidence: 1.0',
          colors['mapping'], alpha=0.9)

# ML Auto-Mapping
create_box(ax, 10.5, 9.7, 2, 0.8, 'ML Pattern Match\nLevenshtein + Fuzzy\nConfidence: 0.6-0.95',
          colors['mapping'], alpha=0.9)

# LLM Mapping
create_box(ax, 10.5, 8.6, 2, 0.8, 'LLM Cortex AI\nSemantic matching\nConfidence: 0.7-1.0',
          colors['mapping'], alpha=0.9)

# Arrows from Streamlit to Mapping methods
create_arrow(ax, 8, 20, 11.5, 11.6, 'Configure\nMappings', color='#E65100')

# Arrow from Mapping to Field Mappings metadata
create_arrow(ax, 10.5, 10, 3, 12.9, 'Store\nMappings', color='#E65100')

# ============================================================================
# TASK 3: TRANSFORMATION
# ============================================================================

create_box(ax, 5, 11.8, 5, 1.2, 'Task 3: SILVER_TRANSFORMATION_TASK\nAfter: Task 2 Completes\nTransform Bronze → Silver',
          colors['task'])

# Arrow from Task 2 to Task 3
create_arrow(ax, 7.5, 13.8, 7.5, 13, 'Execute')

# transform_bronze_to_silver Procedure
create_box(ax, 5, 10, 5, 1.5, 'transform_bronze_to_silver()\n• Apply field mappings\n• Execute rules engine\n• Batch processing\n• Watermark tracking',
          colors['procedure'])

# Arrow from Task 3 to Procedure
create_arrow(ax, 7.5, 11.8, 7.5, 11.5, 'Call')

# Arrows from metadata to transformation
create_arrow(ax, 3, 12.9, 5, 10.75, 'Read\nMappings', color='#1976D2')
create_arrow(ax, 3, 11.2, 5, 10.75, 'Read\nRules', color='#388E3C')

# ============================================================================
# RULES ENGINE LAYER
# ============================================================================

ax.text(14, 10.5, 'Rules Engine', ha='center', fontsize=11, weight='bold',
       bbox=dict(boxstyle='round,pad=0.3', facecolor=colors['rules'], alpha=0.7))

# Data Quality Rules
create_box(ax, 13, 9.5, 2, 0.7, 'Data Quality\nNOT NULL, Range, Format',
          colors['rules'], alpha=0.9)

# Business Logic Rules
create_box(ax, 13, 8.6, 2, 0.7, 'Business Logic\nDefaults, Calculations',
          colors['rules'], alpha=0.9)

# Standardization Rules
create_box(ax, 13, 7.7, 2, 0.7, 'Standardization\nDates, Text, Formats',
          colors['rules'], alpha=0.9)

# Deduplication Rules
create_box(ax, 13, 6.8, 2, 0.7, 'Deduplication\nUnique key matching',
          colors['rules'], alpha=0.9)

# Arrow from transformation to rules
create_arrow(ax, 10, 10.75, 13, 9.1, 'Apply\nRules', color='#388E3C')

# ============================================================================
# SILVER TARGET TABLES
# ============================================================================

create_box(ax, 5.5, 8, 4, 1.2, 'SILVER TARGET TABLES\nDynamic schema-based tables\nCleansed & transformed data',
          colors['table'])

# Arrow from transformation to Silver tables
create_arrow(ax, 7.5, 10, 7.5, 9.2, 'Insert/Merge')

# ============================================================================
# PROCESSING LOG & WATERMARKS
# ============================================================================

create_box(ax, 10.5, 8, 2, 0.6, 'SILVER_PROCESSING_LOG\nBatch tracking',
          colors['metadata'], alpha=0.7)

create_box(ax, 10.5, 7.2, 2, 0.6, 'PROCESSING_WATERMARKS\nIncremental load tracking',
          colors['metadata'], alpha=0.7)

# Arrows from transformation to logs
create_arrow(ax, 10, 10.5, 11.5, 8.6, 'Log\nBatch', color='#757575')
create_arrow(ax, 10, 10.3, 11.5, 7.8, 'Update\nWatermark', color='#757575')

# ============================================================================
# TASK 4: QUALITY CHECK
# ============================================================================

create_box(ax, 5, 6.5, 5, 1.2, 'Task 4: SILVER_QUALITY_CHECK_TASK\nAfter: Task 3 Completes\nValidate data quality',
          colors['task'])

# Arrow from Task 3 to Task 4
create_arrow(ax, 7.5, 8, 7.5, 7.7, 'Execute')

# Quality check procedures
create_box(ax, 11, 6.5, 3, 1.2, 'Quality Validation\n• Check metrics\n• Calculate scores\n• Identify violations',
          colors['quality'])

# Arrow from Task 4 to Quality procedures
create_arrow(ax, 10, 7.1, 11, 7.1, 'Call')

# ============================================================================
# DATA QUALITY METRICS & QUARANTINE
# ============================================================================

create_box(ax, 11, 5, 3, 0.8, 'DATA_QUALITY_METRICS\nRule results • Pass/Fail • Scores',
          colors['quality'])

create_box(ax, 11, 3.9, 3, 0.8, 'QUARANTINE_RECORDS\nFailed records • Error details',
          colors['quality'])

# Arrows from Quality check to metrics
create_arrow(ax, 12.5, 6.5, 12.5, 5.8, 'Record\nMetrics')
create_arrow(ax, 13, 6.5, 13, 4.7, 'Quarantine\nFailed', color='#D32F2F')

# Arrow from Quality metrics to Streamlit
create_arrow(ax, 12.5, 5.8, 6.25, 19.5, 'View\nMetrics', color='#00796B')

# ============================================================================
# TASK 5 & 6: PUBLISH / QUARANTINE
# ============================================================================

# Publish Task
create_box(ax, 2, 5, 3.5, 1, 'Task 5: SILVER_PUBLISH_TASK\nAfter: Task 4 (Quality Pass)\nPublish to downstream',
          colors['task'])

# Quarantine Task
create_box(ax, 14.5, 5, 3.5, 1, 'Task 6: SILVER_QUARANTINE_TASK\nAfter: Task 4 (Quality Fail)\nIsolate bad data',
          colors['task'])

# Arrows from Task 4 to Task 5 and 6
create_arrow(ax, 5, 7.1, 3.75, 6, 'Pass', color='#388E3C')
create_arrow(ax, 10, 7.1, 16.25, 6, 'Fail', color='#D32F2F')

# ============================================================================
# PUBLISHED SILVER DATA
# ============================================================================

create_box(ax, 2, 3.2, 3.5, 1.2, 'PUBLISHED SILVER DATA\nQuality-assured\nReady for Gold/Analytics',
          colors['table'])

# Arrow from Publish task to Published data
create_arrow(ax, 3.75, 5, 3.75, 4.4, 'Publish')

# ============================================================================
# DOWNSTREAM CONSUMERS
# ============================================================================

ax.text(3.75, 2.8, 'Downstream Consumers', ha='center', fontsize=10, weight='bold')

# Gold Layer
create_box(ax, 1, 1.5, 2, 0.8, '🥇 Gold Layer\nAggregations\nDimensional Models',
          '#FFD700', alpha=0.7)

# Analytics
create_box(ax, 3.5, 1.5, 2, 0.8, '📊 Analytics\nBI Tools\nDashboards',
          '#4FC3F7', alpha=0.7)

# ML/AI
create_box(ax, 6, 1.5, 2, 0.8, '🤖 ML/AI\nFeature Engineering\nModel Training',
          '#BA68C8', alpha=0.7)

# Arrows from Published data to consumers
create_arrow(ax, 2, 3.2, 2, 2.3, '')
create_arrow(ax, 3.75, 3.2, 4.5, 2.3, '')
create_arrow(ax, 5.5, 3.2, 7, 2.3, '')

# ============================================================================
# MONITORING & OBSERVABILITY (Right side)
# ============================================================================

ax.text(16.5, 3, 'Monitoring & Observability', ha='left', fontsize=10, weight='bold',
       bbox=dict(boxstyle='round,pad=0.3', facecolor='#B2DFDB', alpha=0.7))

monitoring_items = [
    '✓ Task execution history',
    '✓ Transformation metrics',
    '✓ Data quality scores',
    '✓ Mapping confidence',
    '✓ Rule execution stats',
    '✓ Quarantine alerts',
    '✓ Processing watermarks',
    '✓ Performance metrics',
]

y_pos = 2.5
for item in monitoring_items:
    ax.text(16.7, y_pos, item, ha='left', fontsize=7)
    y_pos -= 0.25

# Arrow from Streamlit to Monitoring
create_arrow(ax, 8, 20.5, 17.5, 3, 'Monitor\nAll', color='#00796B')

# ============================================================================
# FOOTER
# ============================================================================

ax.text(10, 0.5, 'Snowflake Native Architecture • Metadata-Driven • ML/LLM Enhanced • Event-Driven Processing',
       ha='center', va='center', fontsize=9, style='italic', color='#666')

# ============================================================================
# Save the figure
# ============================================================================

plt.tight_layout()
plt.savefig('workflow_diagram_silver_professional.png', dpi=300, bbox_inches='tight',
           facecolor='white', edgecolor='none')
print("✓ Silver layer workflow diagram generated: workflow_diagram_silver_professional.png")
plt.close()

