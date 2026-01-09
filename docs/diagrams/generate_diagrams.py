"""
Generate architecture and data flow diagrams for the Snowflake File Processing Pipeline
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import matplotlib.lines as mlines

# Set style
plt.style.use('default')

def create_bronze_layer_diagram():
    """Create Bronze Layer architecture diagram"""
    fig, ax = plt.subplots(figsize=(18, 12))
    ax.set_xlim(0, 18)
    ax.set_ylim(0, 12)
    ax.axis('off')
    
    # Title
    ax.text(9, 11.2, 'Bronze Layer - Data Ingestion Architecture', 
            ha='center', fontsize=22, fontweight='bold')
    
    # Color scheme
    stage_color = '#E8F4F8'
    table_color = '#FFF4E6'
    task_color = '#E8F5E9'
    streamlit_color = '#F3E5F5'
    
    # Stages (Top) - Better spacing
    stages_y = 9
    stage_width = 2.5
    stage_height = 1.2
    
    ax.add_patch(FancyBboxPatch((0.8, stages_y), stage_width, stage_height, boxstyle="round,pad=0.1", 
                                 facecolor=stage_color, edgecolor='#0277BD', linewidth=2))
    ax.text(2.05, stages_y + 0.6, '@SRC\n(Landing)', ha='center', va='center', fontsize=10, fontweight='bold')
    
    ax.add_patch(FancyBboxPatch((3.8, stages_y), stage_width, stage_height, boxstyle="round,pad=0.1", 
                                 facecolor=stage_color, edgecolor='#0277BD', linewidth=2))
    ax.text(5.05, stages_y + 0.6, '@COMPLETED\n(30 days)', ha='center', va='center', fontsize=10, fontweight='bold')
    
    ax.add_patch(FancyBboxPatch((6.8, stages_y), stage_width, stage_height, boxstyle="round,pad=0.1", 
                                 facecolor=stage_color, edgecolor='#0277BD', linewidth=2))
    ax.text(8.05, stages_y + 0.6, '@ERROR\n(30 days)', ha='center', va='center', fontsize=10, fontweight='bold')
    
    ax.add_patch(FancyBboxPatch((9.8, stages_y), stage_width, stage_height, boxstyle="round,pad=0.1", 
                                 facecolor=stage_color, edgecolor='#0277BD', linewidth=2))
    ax.text(11.05, stages_y + 0.6, '@ARCHIVE\n(Long-term)', ha='center', va='center', fontsize=10, fontweight='bold')
    
    # Tables (Middle) - Better spacing
    tables_y = 6.5
    ax.add_patch(FancyBboxPatch((2, tables_y), 3.5, 1.3, boxstyle="round,pad=0.1", 
                                 facecolor=table_color, edgecolor='#F57C00', linewidth=2))
    ax.text(3.75, tables_y + 0.65, 'RAW_DATA_TABLE\n(VARIANT + Metadata)', ha='center', va='center', fontsize=10, fontweight='bold')
    
    ax.add_patch(FancyBboxPatch((6.5, tables_y), 3.5, 1.3, boxstyle="round,pad=0.1", 
                                 facecolor=table_color, edgecolor='#F57C00', linewidth=2))
    ax.text(8.25, tables_y + 0.65, 'file_processing_queue\n(Status Tracking)', ha='center', va='center', fontsize=10, fontweight='bold')
    
    # Task Pipeline (Bottom) - Better spacing
    tasks_y = 2.5
    task_width = 2.5
    task_height = 1.5
    
    # Task 1: Discover
    ax.add_patch(FancyBboxPatch((0.5, tasks_y), task_width, task_height, boxstyle="round,pad=0.1", 
                                 facecolor=task_color, edgecolor='#388E3C', linewidth=2))
    ax.text(1.75, tasks_y + 1.0, '1️⃣ discover_files_task', ha='center', fontsize=9, fontweight='bold')
    ax.text(1.75, tasks_y + 0.5, 'Every 60 min', ha='center', fontsize=8, style='italic')
    
    # Task 2: Process
    ax.add_patch(FancyBboxPatch((3.5, tasks_y), task_width, task_height, boxstyle="round,pad=0.1", 
                                 facecolor=task_color, edgecolor='#388E3C', linewidth=2))
    ax.text(4.75, tasks_y + 1.0, '2️⃣ process_files_task', ha='center', fontsize=9, fontweight='bold')
    ax.text(4.75, tasks_y + 0.5, 'After discovery', ha='center', fontsize=8, style='italic')
    
    # Task 3: Move Success
    ax.add_patch(FancyBboxPatch((7, tasks_y + 1.0), task_width, task_height, boxstyle="round,pad=0.1", 
                                 facecolor=task_color, edgecolor='#388E3C', linewidth=2))
    ax.text(8.25, tasks_y + 2.0, '3️⃣ move_successful', ha='center', fontsize=9, fontweight='bold')
    ax.text(8.25, tasks_y + 1.5, 'Parallel', ha='center', fontsize=8, style='italic')
    
    # Task 4: Move Failed
    ax.add_patch(FancyBboxPatch((7, tasks_y - 0.5), task_width, task_height, boxstyle="round,pad=0.1", 
                                 facecolor=task_color, edgecolor='#388E3C', linewidth=2))
    ax.text(8.25, tasks_y + 0.5, '4️⃣ move_failed', ha='center', fontsize=9, fontweight='bold')
    ax.text(8.25, tasks_y + 0.0, 'Parallel', ha='center', fontsize=8, style='italic')
    
    # Task 5: Archive
    ax.add_patch(FancyBboxPatch((10.5, tasks_y), task_width, task_height, boxstyle="round,pad=0.1", 
                                 facecolor=task_color, edgecolor='#388E3C', linewidth=2))
    ax.text(11.75, tasks_y + 1.0, '5️⃣ archive_old_files', ha='center', fontsize=9, fontweight='bold')
    ax.text(11.75, tasks_y + 0.5, 'Daily 2 AM', ha='center', fontsize=8, style='italic')
    
    # Streamlit App (Right)
    ax.add_patch(FancyBboxPatch((14.5, 5.5), 3, 4, boxstyle="round,pad=0.1", 
                                 facecolor=streamlit_color, edgecolor='#7B1FA2', linewidth=2))
    ax.text(16, 9.0, '📱 Streamlit App', ha='center', fontsize=11, fontweight='bold')
    ax.text(16, 8.4, '• Upload Files', ha='center', fontsize=9)
    ax.text(16, 7.9, '• Monitor Status', ha='center', fontsize=9)
    ax.text(16, 7.4, '• View Stages', ha='center', fontsize=9)
    ax.text(16, 6.9, '• Manage Tasks', ha='center', fontsize=9)
    ax.text(16, 6.4, '• View History', ha='center', fontsize=9)
    ax.text(16, 5.9, '• Error Review', ha='center', fontsize=9)
    
    # Arrows showing data flow
    arrow_props = dict(arrowstyle='->', lw=2, color='#1976D2')
    
    # Stage to Discovery
    ax.annotate('', xy=(1.75, tasks_y + task_height), xytext=(2.05, stages_y),
                arrowprops=arrow_props)
    
    # Discovery to Process
    ax.annotate('', xy=(3.5, tasks_y + 0.75), xytext=(3.0, tasks_y + 0.75),
                arrowprops=arrow_props)
    
    # Process to Move tasks
    ax.annotate('', xy=(7.0, tasks_y + 1.75), xytext=(6.0, tasks_y + 1.2),
                arrowprops=arrow_props)
    ax.annotate('', xy=(7.0, tasks_y + 0.5), xytext=(6.0, tasks_y + 0.5),
                arrowprops=arrow_props)
    
    # Process to Tables
    ax.annotate('', xy=(3.75, tables_y), xytext=(4.75, tasks_y + task_height),
                arrowprops=arrow_props)
    
    # Streamlit to Stages
    ax.annotate('', xy=(3.3, stages_y + 0.3), xytext=(14.5, 7.5),
                arrowprops=dict(arrowstyle='<->', lw=2, color='#7B1FA2', linestyle='dashed'))
    
    # Legend
    legend_elements = [
        mpatches.Patch(facecolor=stage_color, edgecolor='#0277BD', label='Stages'),
        mpatches.Patch(facecolor=table_color, edgecolor='#F57C00', label='Tables'),
        mpatches.Patch(facecolor=task_color, edgecolor='#388E3C', label='Tasks'),
        mpatches.Patch(facecolor=streamlit_color, edgecolor='#7B1FA2', label='Streamlit UI')
    ]
    ax.legend(handles=legend_elements, loc='lower right', fontsize=10, framealpha=0.9)
    
    plt.tight_layout()
    plt.savefig('bronze_architecture.png', dpi=300, bbox_inches='tight')
    print("✓ Generated: bronze_architecture.png")
    plt.close()

def create_silver_layer_diagram():
    """Create Silver Layer architecture diagram"""
    fig, ax = plt.subplots(figsize=(20, 14))
    ax.set_xlim(0, 20)
    ax.set_ylim(0, 14)
    ax.axis('off')
    
    # Title
    ax.text(10, 13.2, 'Silver Layer - Data Transformation Architecture', 
            ha='center', fontsize=22, fontweight='bold')
    
    # Color scheme
    metadata_color = '#FFF9C4'
    engine_color = '#E1F5FE'
    target_color = '#F1F8E9'
    task_color = '#E8F5E9'
    streamlit_color = '#F3E5F5'
    
    # Bronze Input (Top)
    ax.add_patch(FancyBboxPatch((7.5, 11.5), 5, 1, boxstyle="round,pad=0.1", 
                                 facecolor='#FFE0B2', edgecolor='#F57C00', linewidth=2))
    ax.text(10, 12, '🥉 Bronze: RAW_DATA_TABLE', ha='center', va='center', fontsize=12, fontweight='bold')
    
    # Metadata Tables (Left) - Better spacing
    metadata_y = 8.5
    ax.add_patch(FancyBboxPatch((0.5, metadata_y + 2), 3, 0.9, boxstyle="round,pad=0.1", 
                                 facecolor=metadata_color, edgecolor='#F9A825', linewidth=2))
    ax.text(2, metadata_y + 2.45, 'target_schemas', ha='center', fontsize=10, fontweight='bold')
    
    ax.add_patch(FancyBboxPatch((0.5, metadata_y + 0.9), 3, 0.9, boxstyle="round,pad=0.1", 
                                 facecolor=metadata_color, edgecolor='#F9A825', linewidth=2))
    ax.text(2, metadata_y + 1.35, 'field_mappings', ha='center', fontsize=10, fontweight='bold')
    
    ax.add_patch(FancyBboxPatch((0.5, metadata_y - 0.2), 3, 0.9, boxstyle="round,pad=0.1", 
                                 facecolor=metadata_color, edgecolor='#F9A825', linewidth=2))
    ax.text(2, metadata_y + 0.25, 'transformation_rules', ha='center', fontsize=10, fontweight='bold')
    
    ax.text(2, metadata_y - 0.8, '📋 Metadata', ha='center', fontsize=11, fontweight='bold', style='italic')
    
    # Mapping Engine (Center Top) - Better spacing
    engine_y = 7.5
    ax.add_patch(FancyBboxPatch((4.5, engine_y), 11, 2.8, boxstyle="round,pad=0.1", 
                                 facecolor=engine_color, edgecolor='#0277BD', linewidth=2))
    ax.text(10, engine_y + 2.3, '🗺️ Field Mapping Engine', ha='center', fontsize=13, fontweight='bold')
    
    # Three mapping methods - Better spacing
    ax.add_patch(FancyBboxPatch((5.2, engine_y + 0.4), 2.8, 1.3, boxstyle="round,pad=0.05", 
                                 facecolor='white', edgecolor='#0277BD', linewidth=1.5))
    ax.text(6.6, engine_y + 1.3, '📝 Manual CSV', ha='center', fontsize=10, fontweight='bold')
    ax.text(6.6, engine_y + 0.8, 'User-defined', ha='center', fontsize=8, style='italic')
    
    ax.add_patch(FancyBboxPatch((8.6, engine_y + 0.4), 2.8, 1.3, boxstyle="round,pad=0.05", 
                                 facecolor='white', edgecolor='#0277BD', linewidth=1.5))
    ax.text(10, engine_y + 1.3, '🤖 ML Pattern', ha='center', fontsize=10, fontweight='bold')
    ax.text(10, engine_y + 0.8, 'Similarity', ha='center', fontsize=8, style='italic')
    
    ax.add_patch(FancyBboxPatch((12, engine_y + 0.4), 2.8, 1.3, boxstyle="round,pad=0.05", 
                                 facecolor='white', edgecolor='#0277BD', linewidth=1.5))
    ax.text(13.4, engine_y + 1.3, '🧠 LLM Cortex', ha='center', fontsize=10, fontweight='bold')
    ax.text(13.4, engine_y + 0.8, 'Semantic', ha='center', fontsize=8, style='italic')
    
    # Rules Engine (Center Bottom) - Better spacing
    rules_y = 4
    ax.add_patch(FancyBboxPatch((4.5, rules_y), 11, 2.8, boxstyle="round,pad=0.1", 
                                 facecolor='#FFF3E0', edgecolor='#EF6C00', linewidth=2))
    ax.text(10, rules_y + 2.3, '⚙️ Rules Engine', ha='center', fontsize=13, fontweight='bold')
    
    # Four rule types - Better spacing
    ax.add_patch(FancyBboxPatch((5, rules_y + 0.4), 2.3, 1.3, boxstyle="round,pad=0.05", 
                                 facecolor='white', edgecolor='#EF6C00', linewidth=1.5))
    ax.text(6.15, rules_y + 1.3, '✓ Data Quality', ha='center', fontsize=9, fontweight='bold')
    ax.text(6.15, rules_y + 0.8, 'Validation', ha='center', fontsize=8, style='italic')
    
    ax.add_patch(FancyBboxPatch((7.7, rules_y + 0.4), 2.3, 1.3, boxstyle="round,pad=0.05", 
                                 facecolor='white', edgecolor='#EF6C00', linewidth=1.5))
    ax.text(8.85, rules_y + 1.3, '💼 Business', ha='center', fontsize=9, fontweight='bold')
    ax.text(8.85, rules_y + 0.8, 'Logic', ha='center', fontsize=8, style='italic')
    
    ax.add_patch(FancyBboxPatch((10.4, rules_y + 0.4), 2.3, 1.3, boxstyle="round,pad=0.05", 
                                 facecolor='white', edgecolor='#EF6C00', linewidth=1.5))
    ax.text(11.55, rules_y + 1.3, '📏 Standard', ha='center', fontsize=9, fontweight='bold')
    ax.text(11.55, rules_y + 0.8, 'Format', ha='center', fontsize=8, style='italic')
    
    ax.add_patch(FancyBboxPatch((13.1, rules_y + 0.4), 2.3, 1.3, boxstyle="round,pad=0.05", 
                                 facecolor='white', edgecolor='#EF6C00', linewidth=1.5))
    ax.text(14.25, rules_y + 1.3, '🔍 Dedupe', ha='center', fontsize=9, fontweight='bold')
    ax.text(14.25, rules_y + 0.8, 'Unique', ha='center', fontsize=8, style='italic')
    
    # Silver Target Tables (Bottom)
    target_y = 2
    ax.add_patch(FancyBboxPatch((5.5, target_y), 9, 1.5, boxstyle="round,pad=0.1", 
                                 facecolor=target_color, edgecolor='#558B2F', linewidth=2))
    ax.text(10, target_y + 1.0, '🥈 Silver Layer Tables', ha='center', fontsize=13, fontweight='bold')
    ax.text(10, target_y + 0.4, 'Clean, Standardized, Quality-Checked Data', ha='center', fontsize=10, style='italic')
    
    # Task Pipeline (Bottom) - Better spacing
    task_y = 0.3
    task_width = 2.5
    
    ax.add_patch(FancyBboxPatch((1, task_y), task_width, 1, boxstyle="round,pad=0.05", 
                                 facecolor=task_color, edgecolor='#388E3C', linewidth=1.5))
    ax.text(2.25, task_y + 0.5, '1️⃣ Discovery', ha='center', fontsize=9, fontweight='bold')
    
    ax.add_patch(FancyBboxPatch((4, task_y), task_width, 1, boxstyle="round,pad=0.05", 
                                 facecolor=task_color, edgecolor='#388E3C', linewidth=1.5))
    ax.text(5.25, task_y + 0.5, '2️⃣ Transform', ha='center', fontsize=9, fontweight='bold')
    
    ax.add_patch(FancyBboxPatch((7, task_y), task_width, 1, boxstyle="round,pad=0.05", 
                                 facecolor=task_color, edgecolor='#388E3C', linewidth=1.5))
    ax.text(8.25, task_y + 0.5, '3️⃣ Quality', ha='center', fontsize=9, fontweight='bold')
    
    ax.add_patch(FancyBboxPatch((10, task_y), task_width, 1, boxstyle="round,pad=0.05", 
                                 facecolor=task_color, edgecolor='#388E3C', linewidth=1.5))
    ax.text(11.25, task_y + 0.5, '4️⃣ Publish', ha='center', fontsize=9, fontweight='bold')
    
    ax.add_patch(FancyBboxPatch((13, task_y), task_width, 1, boxstyle="round,pad=0.05", 
                                 facecolor=task_color, edgecolor='#388E3C', linewidth=1.5))
    ax.text(14.25, task_y + 0.5, '5️⃣ Quarantine', ha='center', fontsize=9, fontweight='bold')
    
    # Streamlit App (Right)
    ax.add_patch(FancyBboxPatch((16.5, 6), 3, 5.5, boxstyle="round,pad=0.1", 
                                 facecolor=streamlit_color, edgecolor='#7B1FA2', linewidth=2))
    ax.text(18, 11, '📱 Silver Manager', ha='center', fontsize=12, fontweight='bold')
    ax.text(18, 10.3, '• Schema Designer', ha='center', fontsize=9)
    ax.text(18, 9.7, '• Field Mapper', ha='center', fontsize=9)
    ax.text(18, 9.1, '• Rules Engine', ha='center', fontsize=9)
    ax.text(18, 8.5, '• Transform Monitor', ha='center', fontsize=9)
    ax.text(18, 7.9, '• Quality Metrics', ha='center', fontsize=9)
    ax.text(18, 7.3, '• Task Management', ha='center', fontsize=9)
    ax.text(18, 6.7, '• Quarantine View', ha='center', fontsize=9)
    
    # Arrows
    arrow_props = dict(arrowstyle='->', lw=2, color='#1976D2')
    
    # Bronze to Mapping
    ax.annotate('', xy=(10, engine_y + 2.8), xytext=(10, 11.5),
                arrowprops=arrow_props)
    
    # Metadata to Mapping
    ax.annotate('', xy=(4.5, engine_y + 1.4), xytext=(3.5, metadata_y + 1.4),
                arrowprops=dict(arrowstyle='->', lw=2, color='#F9A825'))
    
    # Mapping to Rules
    ax.annotate('', xy=(10, rules_y + 2.8), xytext=(10, engine_y),
                arrowprops=arrow_props)
    
    # Rules to Silver
    ax.annotate('', xy=(10, target_y + 1.5), xytext=(10, rules_y),
                arrowprops=arrow_props)
    
    # Tasks flow
    for i in range(4):
        start_x = 1 + (i * 3) + task_width
        end_x = 1 + ((i + 1) * 3)
        ax.annotate('', xy=(end_x, task_y + 0.5), xytext=(start_x, task_y + 0.5),
                    arrowprops=dict(arrowstyle='->', lw=1.5, color='#388E3C'))
    
    # Legend
    legend_elements = [
        mpatches.Patch(facecolor=metadata_color, edgecolor='#F9A825', label='Metadata'),
        mpatches.Patch(facecolor=engine_color, edgecolor='#0277BD', label='Mapping Engine'),
        mpatches.Patch(facecolor='#FFF3E0', edgecolor='#EF6C00', label='Rules Engine'),
        mpatches.Patch(facecolor=target_color, edgecolor='#558B2F', label='Silver Tables'),
        mpatches.Patch(facecolor=streamlit_color, edgecolor='#7B1FA2', label='Streamlit UI')
    ]
    ax.legend(handles=legend_elements, loc='lower left', fontsize=10, framealpha=0.9)
    
    plt.tight_layout()
    plt.savefig('silver_architecture.png', dpi=300, bbox_inches='tight')
    print("✓ Generated: silver_architecture.png")
    plt.close()

def create_overall_data_flow():
    """Create overall data flow diagram"""
    fig, ax = plt.subplots(figsize=(16, 12))
    ax.set_xlim(0, 16)
    ax.set_ylim(0, 12)
    ax.axis('off')
    
    # Title
    ax.text(8, 11.3, 'End-to-End Data Flow - Medallion Architecture', 
            ha='center', fontsize=20, fontweight='bold')
    
    # Bronze Layer - Better spacing
    ax.add_patch(FancyBboxPatch((1, 7.5), 4, 2.8, boxstyle="round,pad=0.1", 
                                 facecolor='#FFE0B2', edgecolor='#F57C00', linewidth=3))
    ax.text(3, 10, '🥉 BRONZE LAYER', ha='center', fontsize=13, fontweight='bold')
    ax.text(3, 9.4, 'Raw Data Ingestion', ha='center', fontsize=10, style='italic')
    ax.text(1.5, 8.9, '• CSV/Excel Files', ha='left', fontsize=9)
    ax.text(1.5, 8.5, '• VARIANT Storage', ha='left', fontsize=9)
    ax.text(1.5, 8.1, '• File Tracking', ha='left', fontsize=9)
    ax.text(1.5, 7.7, '• Auto Discovery', ha='left', fontsize=9)
    
    # Silver Layer - Better spacing
    ax.add_patch(FancyBboxPatch((6, 7.5), 4, 2.8, boxstyle="round,pad=0.1", 
                                 facecolor='#E8F5E9', edgecolor='#388E3C', linewidth=3))
    ax.text(8, 10, '🥈 SILVER LAYER', ha='center', fontsize=13, fontweight='bold')
    ax.text(8, 9.4, 'Clean & Standardized', ha='center', fontsize=10, style='italic')
    ax.text(6.5, 8.9, '• Field Mapping', ha='left', fontsize=9)
    ax.text(6.5, 8.5, '• Quality Rules', ha='left', fontsize=9)
    ax.text(6.5, 8.1, '• Deduplication', ha='left', fontsize=9)
    ax.text(6.5, 7.7, '• Validation', ha='left', fontsize=9)
    
    # Gold Layer (Future) - Better spacing
    ax.add_patch(FancyBboxPatch((11, 7.5), 4, 2.8, boxstyle="round,pad=0.1", 
                                 facecolor='#FFF9C4', edgecolor='#F9A825', linewidth=3, linestyle='dashed'))
    ax.text(13, 10, '🥇 GOLD LAYER', ha='center', fontsize=13, fontweight='bold')
    ax.text(13, 9.4, 'Business Ready', ha='center', fontsize=10, style='italic')
    ax.text(11.5, 8.9, '• Aggregations', ha='left', fontsize=9)
    ax.text(11.5, 8.5, '• Business Metrics', ha='left', fontsize=9)
    ax.text(11.5, 8.1, '• Analytics Ready', ha='left', fontsize=9)
    ax.text(11.5, 7.7, '• KPI Dashboards', ha='left', fontsize=9)
    
    # Data Sources (Top) - Better spacing
    sources_y = 5
    ax.add_patch(FancyBboxPatch((0.5, sources_y), 2, 1, boxstyle="round,pad=0.05", 
                                 facecolor='#BBDEFB', edgecolor='#1976D2', linewidth=2))
    ax.text(1.5, sources_y + 0.5, '📄 CSV Files', ha='center', fontsize=10, fontweight='bold')
    
    ax.add_patch(FancyBboxPatch((3, sources_y), 2, 1, boxstyle="round,pad=0.05", 
                                 facecolor='#BBDEFB', edgecolor='#1976D2', linewidth=2))
    ax.text(4, sources_y + 0.5, '📊 Excel Files', ha='center', fontsize=10, fontweight='bold')
    
    # Consumers (Bottom) - Better spacing
    consumers_y = 2.5
    ax.add_patch(FancyBboxPatch((10, consumers_y), 2.2, 1, boxstyle="round,pad=0.05", 
                                 facecolor='#F3E5F5', edgecolor='#7B1FA2', linewidth=2))
    ax.text(11.1, consumers_y + 0.5, '📊 BI Tools', ha='center', fontsize=10, fontweight='bold')
    
    ax.add_patch(FancyBboxPatch((12.8, consumers_y), 2.2, 1, boxstyle="round,pad=0.05", 
                                 facecolor='#F3E5F5', edgecolor='#7B1FA2', linewidth=2))
    ax.text(13.9, consumers_y + 0.5, '🤖 ML Models', ha='center', fontsize=10, fontweight='bold')
    
    # Arrows
    arrow_props = dict(arrowstyle='->', lw=3, color='#1976D2')
    
    # Sources to Bronze
    ax.annotate('', xy=(3, 7.5), xytext=(1.5, sources_y + 1),
                arrowprops=arrow_props)
    ax.annotate('', xy=(3, 7.5), xytext=(4, sources_y + 1),
                arrowprops=arrow_props)
    
    # Bronze to Silver
    ax.annotate('', xy=(6, 8.9), xytext=(5, 8.9),
                arrowprops=arrow_props)
    
    # Silver to Gold
    ax.annotate('', xy=(11, 8.9), xytext=(10, 8.9),
                arrowprops=dict(arrowstyle='->', lw=3, color='#1976D2', linestyle='dashed'))
    
    # Gold to Consumers
    ax.annotate('', xy=(11.1, consumers_y + 1), xytext=(13, 7.5),
                arrowprops=dict(arrowstyle='->', lw=2, color='#7B1FA2', linestyle='dashed'))
    ax.annotate('', xy=(13.9, consumers_y + 1), xytext=(13, 7.5),
                arrowprops=dict(arrowstyle='->', lw=2, color='#7B1FA2', linestyle='dashed'))
    
    # Processing annotations - Better spacing
    ax.text(4.2, 9.2, 'File Discovery\n& Parsing', ha='center', fontsize=9, 
            bbox=dict(boxstyle='round', facecolor='white', alpha=0.9, edgecolor='#1976D2', linewidth=1.5))
    
    ax.text(7.8, 9.5, 'Mapping\n& Rules', ha='center', fontsize=9,
            bbox=dict(boxstyle='round', facecolor='white', alpha=0.9, edgecolor='#1976D2', linewidth=1.5))
    
    ax.text(10.3, 9.2, 'Aggregation\n& Metrics', ha='center', fontsize=9,
            bbox=dict(boxstyle='round', facecolor='white', alpha=0.9, edgecolor='#F9A825', linewidth=1.5, linestyle='dashed'))
    
    # Key Features Box - Better spacing
    ax.add_patch(FancyBboxPatch((0.5, 0.3), 7, 1.6, boxstyle="round,pad=0.1", 
                                 facecolor='#E3F2FD', edgecolor='#1565C0', linewidth=2))
    ax.text(4, 1.6, '🔑 Key Features', ha='center', fontsize=11, fontweight='bold')
    ax.text(1, 1.2, '• Automated Task Scheduling', ha='left', fontsize=9)
    ax.text(1, 0.8, '• RBAC Security (3 roles)', ha='left', fontsize=9)
    ax.text(4.5, 1.2, '• Streamlit Management UI', ha='left', fontsize=9)
    ax.text(4.5, 0.8, '• Quality Monitoring', ha='left', fontsize=9)
    
    # Status Box - Better spacing
    ax.text(8.5, 1.2, '✅ Implemented', ha='center', fontsize=10, fontweight='bold',
            bbox=dict(boxstyle='round,pad=0.4', facecolor='#C8E6C9', edgecolor='#388E3C', linewidth=2))
    ax.text(8.5, 0.5, '🚧 Future', ha='center', fontsize=10, fontweight='bold',
            bbox=dict(boxstyle='round,pad=0.4', facecolor='#FFF9C4', edgecolor='#F9A825', linewidth=2, linestyle='dashed'))
    
    plt.tight_layout()
    plt.savefig('overall_data_flow.png', dpi=300, bbox_inches='tight')
    print("✓ Generated: overall_data_flow.png")
    plt.close()

def create_project_structure_diagram():
    """Create visual project structure diagram"""
    fig, ax = plt.subplots(figsize=(18, 12))
    ax.set_xlim(0, 18)
    ax.set_ylim(0, 12)
    ax.axis('off')
    
    # Title
    ax.text(9, 11.3, 'Project Structure Overview', 
            ha='center', fontsize=20, fontweight='bold')
    
    # Root level
    root_y = 10.2
    ax.add_patch(FancyBboxPatch((7, root_y), 4, 0.7, boxstyle="round,pad=0.05", 
                                 facecolor='#E3F2FD', edgecolor='#1565C0', linewidth=2))
    ax.text(9, root_y + 0.35, '📁 file_processing_pipeline/', ha='center', fontsize=12, fontweight='bold')
    
    # Main folders - Better spacing
    folders = [
        (1, 8.5, '📂 bronze/', '#FFE0B2'),
        (5.5, 8.5, '📂 silver/', '#E8F5E9'),
        (10, 8.5, '📂 docs/', '#F3E5F5'),
        (14.5, 8.5, '📂 sample_data/', '#FFF9C4')
    ]
    
    for x, y, label, color in folders:
        ax.add_patch(FancyBboxPatch((x, y), 3, 0.6, boxstyle="round,pad=0.05", 
                                     facecolor=color, edgecolor='#424242', linewidth=1.5))
        ax.text(x + 1.5, y + 0.3, label, ha='center', fontsize=11, fontweight='bold')
    
    # Bronze contents - Better spacing
    bronze_items = [
        '1_Setup_Database_Roles.sql',
        '2_Bronze_Schema_Tables.sql',
        '3_Bronze_Setup_Logic.sql',
        '4_Bronze_Tasks.sql',
        'bronze_streamlit/',
        'Reset.sql',
        'README.md'
    ]
    
    y_pos = 7.8
    for item in bronze_items:
        icon = '📁' if '/' in item else '📄'
        ax.text(2.5, y_pos, f'{icon} {item}', ha='center', fontsize=8)
        y_pos -= 0.35
    
    # Silver contents - Better spacing
    silver_items = [
        '1_Silver_Schema_Setup.sql',
        '2_Silver_Target_Schemas.sql',
        '3_Silver_Mapping_Procedures.sql',
        '4_Silver_Rules_Engine.sql',
        '5_Silver_Transformation_Logic.sql',
        '6_Silver_Tasks.sql',
        'silver_streamlit/',
        'mappings/',
        'README.md'
    ]
    
    y_pos = 7.8
    for item in silver_items:
        icon = '📁' if '/' in item else '📄'
        ax.text(7, y_pos, f'{icon} {item}', ha='center', fontsize=8)
        y_pos -= 0.35
    
    # Docs contents - Better spacing
    docs_items = [
        'architecture/',
        'diagrams/',
        'screenshots/',
        'testing/',
        'USER_GUIDE.md',
        'README.md'
    ]
    
    y_pos = 7.8
    for item in docs_items:
        icon = '📁' if '/' in item else '📄'
        ax.text(11.5, y_pos, f'{icon} {item}', ha='center', fontsize=8)
        y_pos -= 0.35
    
    # Sample data contents - Better spacing
    sample_items = [
        'claims_data/',
        'config/',
        'README.md'
    ]
    
    y_pos = 7.8
    for item in sample_items:
        icon = '📁' if '/' in item else '📄'
        ax.text(16, y_pos, f'{icon} {item}', ha='center', fontsize=8)
        y_pos -= 0.35
    
    # Root files - Better spacing
    root_files_y = 4
    ax.text(9, root_files_y + 0.8, 'Root Level Files:', ha='center', fontsize=11, fontweight='bold')
    
    root_files = [
        ('📄 README.md', 2),
        ('📄 QUICK_START.md', 4.5),
        ('📄 default.config', 7),
        ('📄 custom.config.example', 9.5),
        ('🔧 deploy.sh', 12),
        ('🔧 deploy_bronze.sh', 14.5),
        ('🔧 deploy_silver.sh', 2),
        ('🔧 undeploy.sh', 4.5),
        ('🔧 test_deployment.sh', 7),
        ('🔧 validate_structure.sh', 9.5),
    ]
    
    y_pos = root_files_y
    for i, (file, x) in enumerate(root_files):
        if i == 6:  # New row
            y_pos -= 0.5
        ax.text(x, y_pos, file, ha='center', fontsize=8)
    
    # Legend - Better spacing
    legend_y = 1.8
    ax.text(9, legend_y + 0.6, 'Color Legend:', ha='center', fontsize=11, fontweight='bold')
    
    legend_items = [
        (2.5, legend_y, '🥉 Bronze Layer', '#FFE0B2'),
        (6.5, legend_y, '🥈 Silver Layer', '#E8F5E9'),
        (10.5, legend_y, '📚 Documentation', '#F3E5F5'),
        (14.5, legend_y, '📊 Sample Data', '#FFF9C4')
    ]
    
    for x, y, label, color in legend_items:
        ax.add_patch(FancyBboxPatch((x - 1, y - 0.2), 3, 0.4, boxstyle="round,pad=0.02", 
                                     facecolor=color, edgecolor='#424242', linewidth=1))
        ax.text(x + 0.5, y, label, ha='center', fontsize=9)
    
    # Add deployment flow annotation
    ax.text(9, 0.5, '💡 Deployment Order: 1. Bronze → 2. Silver → 3. Streamlit Apps', 
            ha='center', fontsize=9, style='italic',
            bbox=dict(boxstyle='round', facecolor='#FFFDE7', edgecolor='#F57F17', linewidth=1.5))
    
    plt.tight_layout()
    plt.savefig('project_structure.png', dpi=300, bbox_inches='tight')
    print("✓ Generated: project_structure.png")
    plt.close()

if __name__ == "__main__":
    print("Generating architecture diagrams...")
    print()
    
    create_bronze_layer_diagram()
    create_silver_layer_diagram()
    create_overall_data_flow()
    create_project_structure_diagram()
    
    print()
    print("✅ All diagrams generated successfully!")
    print("📁 Location: docs/diagrams/")

