#!/usr/bin/env python3
"""
Generate Architecture Diagrams for System Design Document
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import numpy as np

# Set style
plt.style.use('seaborn-v0_8-darkgrid')
colors = {
    'snowflake': '#29B5E8',
    'bronze': '#CD7F32',
    'silver': '#C0C0C0',
    'gold': '#FFD700',
    'admin': '#FF6B6B',
    'readwrite': '#4ECDC4',
    'readonly': '#95E1D3',
    'background': '#F7F9FC',
    'text': '#2C3E50',
    'border': '#34495E'
}

def create_high_level_architecture():
    """Generate high-level architecture diagram"""
    fig, ax = plt.subplots(figsize=(16, 12))
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis('off')
    
    # Title
    ax.text(50, 95, 'Snowflake File Processing Pipeline', 
            ha='center', va='top', fontsize=24, fontweight='bold', color=colors['text'])
    ax.text(50, 92, 'High-Level Architecture', 
            ha='center', va='top', fontsize=16, color=colors['text'])
    
    # Snowflake Account Container
    snowflake_box = FancyBboxPatch((2, 5), 96, 82, 
                                   boxstyle="round,pad=0.5", 
                                   edgecolor=colors['snowflake'], 
                                   facecolor='white', 
                                   linewidth=3, alpha=0.9)
    ax.add_patch(snowflake_box)
    ax.text(5, 84, 'SNOWFLAKE ACCOUNT', fontsize=14, fontweight='bold', 
            color=colors['snowflake'])
    
    # Database Container
    db_box = FancyBboxPatch((5, 8), 90, 72, 
                            boxstyle="round,pad=0.3", 
                            edgecolor=colors['border'], 
                            facecolor=colors['background'], 
                            linewidth=2, alpha=0.8)
    ax.add_patch(db_box)
    ax.text(50, 77, 'DATABASE: DB_INGEST_PIPELINE', 
            ha='center', fontsize=12, fontweight='bold', color=colors['text'])
    
    # Bronze Layer
    bronze_box = FancyBboxPatch((8, 45), 38, 28, 
                                boxstyle="round,pad=0.3", 
                                edgecolor=colors['bronze'], 
                                facecolor='white', 
                                linewidth=2.5, alpha=0.95)
    ax.add_patch(bronze_box)
    ax.text(27, 71, 'BRONZE LAYER', ha='center', fontsize=11, 
            fontweight='bold', color=colors['bronze'])
    ax.text(27, 68, 'Raw Data Ingestion', ha='center', fontsize=9, 
            style='italic', color=colors['text'])
    
    # Bronze components
    bronze_items = [
        'Stages: SRC, COMPLETED, ERROR, ARCHIVE',
        'Tables: RAW_DATA_TABLE, QUEUE',
        'Tasks: 5 (discover → process → move)',
        'Procedures: 4+ (file processing)'
    ]
    y_pos = 63
    for item in bronze_items:
        ax.text(10, y_pos, f'• {item}', fontsize=8, color=colors['text'])
        y_pos -= 4
    
    # Silver Layer
    silver_box = FancyBboxPatch((54, 45), 38, 28, 
                                boxstyle="round,pad=0.3", 
                                edgecolor=colors['silver'], 
                                facecolor='white', 
                                linewidth=2.5, alpha=0.95)
    ax.add_patch(silver_box)
    ax.text(73, 71, 'SILVER LAYER', ha='center', fontsize=11, 
            fontweight='bold', color=colors['silver'])
    ax.text(73, 68, 'Data Transformation', ha='center', fontsize=9, 
            style='italic', color=colors['text'])
    
    # Silver components
    silver_items = [
        'Metadata: 8 tables (mappings, rules)',
        'Target Tables: Dynamic (CLAIMS, etc.)',
        'Tasks: 6 (transform → validate)',
        'Procedures: 34+ (ML/LLM mapping)'
    ]
    y_pos = 63
    for item in silver_items:
        ax.text(56, y_pos, f'• {item}', fontsize=8, color=colors['text'])
        y_pos -= 4
    
    # Arrow from Bronze to Silver
    arrow = FancyArrowPatch((46, 59), (54, 59),
                           arrowstyle='->', mutation_scale=30, 
                           linewidth=3, color=colors['snowflake'])
    ax.add_patch(arrow)
    ax.text(50, 60.5, 'Transform', ha='center', fontsize=9, 
            fontweight='bold', color=colors['snowflake'])
    
    # Public Schema / Streamlit
    streamlit_box = FancyBboxPatch((8, 12), 84, 28, 
                                   boxstyle="round,pad=0.3", 
                                   edgecolor='#FF4B4B', 
                                   facecolor='white', 
                                   linewidth=2, alpha=0.95)
    ax.add_patch(streamlit_box)
    ax.text(50, 38, 'PUBLIC SCHEMA - Streamlit Applications', 
            ha='center', fontsize=11, fontweight='bold', color='#FF4B4B')
    
    # Streamlit Apps
    app1_box = FancyBboxPatch((12, 18), 35, 16, 
                              boxstyle="round,pad=0.2", 
                              edgecolor=colors['bronze'], 
                              facecolor='#FFF8DC', 
                              linewidth=1.5)
    ax.add_patch(app1_box)
    ax.text(29.5, 31, 'Bronze Ingestion Pipeline', ha='center', 
            fontsize=10, fontweight='bold', color=colors['bronze'])
    ax.text(29.5, 28, '📤 File Upload', ha='center', fontsize=8)
    ax.text(29.5, 25.5, '📊 Processing Status', ha='center', fontsize=8)
    ax.text(29.5, 23, '⚙️ Task Control', ha='center', fontsize=8)
    ax.text(29.5, 20.5, '📈 Monitoring', ha='center', fontsize=8)
    
    app2_box = FancyBboxPatch((53, 18), 35, 16, 
                              boxstyle="round,pad=0.2", 
                              edgecolor=colors['silver'], 
                              facecolor='#F0F8FF', 
                              linewidth=1.5)
    ax.add_patch(app2_box)
    ax.text(70.5, 31, 'Silver Transformation Manager', ha='center', 
            fontsize=10, fontweight='bold', color=colors['silver'])
    ax.text(70.5, 28, '🗺️ Field Mapping', ha='center', fontsize=8)
    ax.text(70.5, 25.5, '📋 Rules Engine', ha='center', fontsize=8)
    ax.text(70.5, 23, '✅ Quality Validation', ha='center', fontsize=8)
    ax.text(70.5, 20.5, '📊 Data Viewer', ha='center', fontsize=8)
    
    # RBAC Section (bottom)
    ax.text(50, 3.5, 'Role-Based Access Control (RBAC)', 
            ha='center', fontsize=10, fontweight='bold', color=colors['text'])
    
    # Role hierarchy
    role_y = 1
    ax.text(30, role_y, 'ADMIN', ha='center', fontsize=9, 
            bbox=dict(boxstyle='round', facecolor=colors['admin'], alpha=0.7))
    ax.text(40, role_y, '→', ha='center', fontsize=12)
    ax.text(50, role_y, 'READWRITE', ha='center', fontsize=9, 
            bbox=dict(boxstyle='round', facecolor=colors['readwrite'], alpha=0.7))
    ax.text(60, role_y, '→', ha='center', fontsize=12)
    ax.text(70, role_y, 'READONLY', ha='center', fontsize=9, 
            bbox=dict(boxstyle='round', facecolor=colors['readonly'], alpha=0.7))
    
    plt.tight_layout()
    plt.savefig('docs/design/images/architecture_overview.png', dpi=300, bbox_inches='tight', 
                facecolor='white', edgecolor='none')
    print("✓ Generated: images/architecture_overview.png")
    plt.close()

def create_data_flow_diagram():
    """Generate data flow diagram"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(18, 10))
    
    # Bronze Layer Flow
    ax1.set_xlim(0, 10)
    ax1.set_ylim(0, 12)
    ax1.axis('off')
    ax1.set_title('Bronze Layer Data Flow', fontsize=16, fontweight='bold', 
                  color=colors['bronze'], pad=20)
    
    steps_bronze = [
        ('File Upload', 11, '#90EE90'),
        ('discover_files_task\n(Every 60 min)', 9.5, colors['bronze']),
        ('process_files_task\n(After discovery)', 8, colors['bronze']),
        ('move_successful_files\n(SUCCESS → COMPLETED)', 6.5, '#4CAF50'),
        ('move_failed_files\n(FAILED → ERROR)', 5, '#FF5252'),
        ('archive_old_files\n(Daily cleanup)', 3.5, '#9E9E9E')
    ]
    
    for i, (label, y, color) in enumerate(steps_bronze):
        box = FancyBboxPatch((1, y-0.4), 8, 0.8, 
                            boxstyle="round,pad=0.1", 
                            edgecolor='black', 
                            facecolor=color, 
                            linewidth=1.5, alpha=0.8)
        ax1.add_patch(box)
        ax1.text(5, y, label, ha='center', va='center', fontsize=9, 
                fontweight='bold')
        
        # Add arrows
        if i < len(steps_bronze) - 1:
            arrow = FancyArrowPatch((5, y-0.5), (5, steps_bronze[i+1][1]+0.4),
                                   arrowstyle='->', mutation_scale=20, 
                                   linewidth=2, color='black')
            ax1.add_patch(arrow)
    
    # Add stage indicators
    ax1.text(9.5, 11, '📁', fontsize=20)
    ax1.text(9.5, 9.5, '🔍', fontsize=20)
    ax1.text(9.5, 8, '⚙️', fontsize=20)
    ax1.text(9.5, 6.5, '✅', fontsize=20)
    ax1.text(9.5, 5, '❌', fontsize=20)
    ax1.text(9.5, 3.5, '📦', fontsize=20)
    
    # Silver Layer Flow
    ax2.set_xlim(0, 10)
    ax2.set_ylim(0, 12)
    ax2.axis('off')
    ax2.set_title('Silver Layer Data Flow', fontsize=16, fontweight='bold', 
                  color=colors['silver'], pad=20)
    
    steps_silver = [
        ('Bronze Data Available', 11, '#90EE90'),
        ('bronze_completion_sensor\n(Every 5 min)', 9.5, colors['silver']),
        ('silver_discovery_task\n(Identify batches)', 8, colors['silver']),
        ('silver_transformation_task\n(Apply mappings & rules)', 6.5, colors['silver']),
        ('silver_quality_check_task\n(Validate data)', 5, '#FFA726'),
    ]
    
    for i, (label, y, color) in enumerate(steps_silver):
        box = FancyBboxPatch((1, y-0.4), 8, 0.8, 
                            boxstyle="round,pad=0.1", 
                            edgecolor='black', 
                            facecolor=color, 
                            linewidth=1.5, alpha=0.8)
        ax2.add_patch(box)
        ax2.text(5, y, label, ha='center', va='center', fontsize=9, 
                fontweight='bold')
        
        # Add arrows
        if i < len(steps_silver) - 1:
            arrow = FancyArrowPatch((5, y-0.5), (5, steps_silver[i+1][1]+0.4),
                                   arrowstyle='->', mutation_scale=20, 
                                   linewidth=2, color='black')
            ax2.add_patch(arrow)
    
    # Final split
    publish_box = FancyBboxPatch((0.5, 2.5), 4, 0.8, 
                                boxstyle="round,pad=0.1", 
                                edgecolor='black', 
                                facecolor='#4CAF50', 
                                linewidth=1.5, alpha=0.8)
    ax2.add_patch(publish_box)
    ax2.text(2.5, 2.9, 'silver_publish_task\n(Quality PASS)', 
            ha='center', va='center', fontsize=8, fontweight='bold')
    
    quarantine_box = FancyBboxPatch((5.5, 2.5), 4, 0.8, 
                                   boxstyle="round,pad=0.1", 
                                   edgecolor='black', 
                                   facecolor='#FF5252', 
                                   linewidth=1.5, alpha=0.8)
    ax2.add_patch(quarantine_box)
    ax2.text(7.5, 2.9, 'silver_quarantine_task\n(Quality FAIL)', 
            ha='center', va='center', fontsize=8, fontweight='bold')
    
    # Arrows to final tasks
    arrow1 = FancyArrowPatch((3.5, 4.5), (2.5, 3.4),
                            arrowstyle='->', mutation_scale=20, 
                            linewidth=2, color='#4CAF50')
    ax2.add_patch(arrow1)
    
    arrow2 = FancyArrowPatch((6.5, 4.5), (7.5, 3.4),
                            arrowstyle='->', mutation_scale=20, 
                            linewidth=2, color='#FF5252')
    ax2.add_patch(arrow2)
    
    # Add icons
    ax2.text(9.5, 11, '📊', fontsize=20)
    ax2.text(9.5, 9.5, '👁️', fontsize=20)
    ax2.text(9.5, 8, '🔍', fontsize=20)
    ax2.text(9.5, 6.5, '🔄', fontsize=20)
    ax2.text(9.5, 5, '✓', fontsize=20)
    
    plt.tight_layout()
    plt.savefig('docs/design/images/data_flow_diagram.png', dpi=300, bbox_inches='tight', 
                facecolor='white', edgecolor='none')
    print("✓ Generated: images/data_flow_diagram.png")
    plt.close()

def create_security_diagram():
    """Generate security and RBAC diagram"""
    fig, ax = plt.subplots(figsize=(14, 10))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    ax.text(5, 9.5, 'Security Architecture & Role-Based Access Control', 
            ha='center', fontsize=16, fontweight='bold', color=colors['text'])
    
    # Role Hierarchy
    ax.text(5, 8.5, 'Role Hierarchy', ha='center', fontsize=13, 
            fontweight='bold', color=colors['text'])
    
    # SYSADMIN (deployment)
    sysadmin_box = FancyBboxPatch((3.5, 7.2), 3, 0.6, 
                                  boxstyle="round,pad=0.1", 
                                  edgecolor='black', 
                                  facecolor='#E3F2FD', 
                                  linewidth=2)
    ax.add_patch(sysadmin_box)
    ax.text(5, 7.5, 'SYSADMIN\n(Deployment)', ha='center', va='center', 
            fontsize=10, fontweight='bold')
    
    # Arrow down
    arrow1 = FancyArrowPatch((5, 7.1), (5, 6.5),
                            arrowstyle='->', mutation_scale=25, 
                            linewidth=2.5, color='black')
    ax.add_patch(arrow1)
    ax.text(5.5, 6.8, 'grants', fontsize=8, style='italic')
    
    # ADMIN Role
    admin_box = FancyBboxPatch((3, 5.7), 4, 0.7, 
                               boxstyle="round,pad=0.1", 
                               edgecolor='black', 
                               facecolor=colors['admin'], 
                               linewidth=2.5, alpha=0.8)
    ax.add_patch(admin_box)
    ax.text(5, 6.05, 'DB_INGEST_PIPELINE_ADMIN\n(Full Access)', 
            ha='center', va='center', fontsize=10, fontweight='bold', color='white')
    
    # Arrow down
    arrow2 = FancyArrowPatch((5, 5.6), (5, 5.0),
                            arrowstyle='->', mutation_scale=25, 
                            linewidth=2.5, color='black')
    ax.add_patch(arrow2)
    ax.text(5.5, 5.3, 'inherits', fontsize=8, style='italic')
    
    # READWRITE Role
    readwrite_box = FancyBboxPatch((3, 4.2), 4, 0.7, 
                                   boxstyle="round,pad=0.1", 
                                   edgecolor='black', 
                                   facecolor=colors['readwrite'], 
                                   linewidth=2.5, alpha=0.8)
    ax.add_patch(readwrite_box)
    ax.text(5, 4.55, 'DB_INGEST_PIPELINE_READWRITE\n(Read/Write Access)', 
            ha='center', va='center', fontsize=10, fontweight='bold')
    
    # Arrow down
    arrow3 = FancyArrowPatch((5, 4.1), (5, 3.5),
                            arrowstyle='->', mutation_scale=25, 
                            linewidth=2.5, color='black')
    ax.add_patch(arrow3)
    ax.text(5.5, 3.8, 'inherits', fontsize=8, style='italic')
    
    # READONLY Role
    readonly_box = FancyBboxPatch((3, 2.7), 4, 0.7, 
                                  boxstyle="round,pad=0.1", 
                                  edgecolor='black', 
                                  facecolor=colors['readonly'], 
                                  linewidth=2.5, alpha=0.8)
    ax.add_patch(readonly_box)
    ax.text(5, 3.05, 'DB_INGEST_PIPELINE_READONLY\n(Read-Only Access)', 
            ha='center', va='center', fontsize=10, fontweight='bold')
    
    # Permissions Matrix
    ax.text(5, 2, 'Permissions Matrix', ha='center', fontsize=12, 
            fontweight='bold', color=colors['text'])
    
    permissions = [
        ('Database', '✓ OWNERSHIP', '✓ USAGE', '✓ USAGE'),
        ('Tables', '✓ ALL', '✓ SELECT/INSERT/UPDATE/DELETE', '✓ SELECT'),
        ('Stages', '✓ ALL', '✓ READ/WRITE', '✓ READ'),
        ('Procedures', '✓ ALL', '✓ USAGE', '✗'),
        ('Tasks', '✓ ALL', '✗', '✗'),
        ('Streamlit', '✓ CREATE', '✗', '✗'),
    ]
    
    y_start = 1.3
    col_widths = [2, 2.5, 2.5, 2.5]
    x_positions = [0.5, 2.5, 5, 7.5]
    
    # Header
    headers = ['Resource', 'ADMIN', 'READWRITE', 'READONLY']
    for i, header in enumerate(headers):
        ax.text(x_positions[i] + col_widths[i]/2, y_start, header, 
                ha='center', fontsize=9, fontweight='bold', 
                bbox=dict(boxstyle='round', facecolor='lightgray', alpha=0.7))
    
    # Rows
    for i, (resource, admin, rw, ro) in enumerate(permissions):
        y = y_start - (i+1) * 0.35
        values = [resource, admin, rw, ro]
        for j, val in enumerate(values):
            color = 'white' if j == 0 else '#E8F5E9' if '✓' in val else '#FFEBEE'
            ax.text(x_positions[j] + col_widths[j]/2, y, val, 
                    ha='center', fontsize=8,
                    bbox=dict(boxstyle='round', facecolor=color, alpha=0.6))
    
    plt.tight_layout()
    plt.savefig('docs/design/images/security_rbac_diagram.png', dpi=300, bbox_inches='tight', 
                facecolor='white', edgecolor='none')
    print("✓ Generated: images/security_rbac_diagram.png")
    plt.close()

def create_deployment_pipeline_diagram():
    """Generate CI/CD deployment pipeline diagram"""
    fig, ax = plt.subplots(figsize=(16, 8))
    ax.set_xlim(0, 11)
    ax.set_ylim(0, 6)
    ax.axis('off')
    
    ax.text(5.5, 5.5, 'CI/CD Deployment Pipeline', 
            ha='center', fontsize=16, fontweight='bold', color=colors['text'])
    
    stages = [
        ('Code\nCommit', 0.5, '#4CAF50', '📝'),
        ('Syntax\nValidation', 1.5, '#2196F3', '✓'),
        ('Linting', 2.5, '#2196F3', '🔍'),
        ('Deploy\nDev', 3.5, '#FF9800', '🚀'),
        ('Integration\nTests', 4.5, '#9C27B0', '🧪'),
        ('Deploy\nStaging', 5.5, '#FF9800', '🚀'),
        ('Smoke\nTests', 6.5, '#9C27B0', '💨'),
        ('Manual\nApproval', 7.5, '#F44336', '👤'),
        ('Deploy\nProd', 8.5, '#4CAF50', '🎯'),
        ('Verify', 9.5, '#4CAF50', '✅'),
    ]
    
    for i, (label, x, color, icon) in enumerate(stages):
        # Box
        box = FancyBboxPatch((x-0.35, 2), 0.7, 1.5, 
                            boxstyle="round,pad=0.1", 
                            edgecolor='black', 
                            facecolor=color, 
                            linewidth=2, alpha=0.7)
        ax.add_patch(box)
        
        # Icon
        ax.text(x, 3.2, icon, ha='center', va='center', fontsize=20)
        
        # Label
        ax.text(x, 2.5, label, ha='center', va='center', fontsize=8, 
                fontweight='bold', color='white')
        
        # Arrow to next stage
        if i < len(stages) - 1:
            arrow = FancyArrowPatch((x+0.35, 2.75), (stages[i+1][1]-0.35, 2.75),
                                   arrowstyle='->', mutation_scale=20, 
                                   linewidth=2, color='black')
            ax.add_patch(arrow)
    
    # Environment labels
    ax.text(3.5, 1.2, 'Development', ha='center', fontsize=10, 
            bbox=dict(boxstyle='round', facecolor='#FFE0B2', alpha=0.7))
    ax.text(5.5, 1.2, 'Staging', ha='center', fontsize=10, 
            bbox=dict(boxstyle='round', facecolor='#FFF9C4', alpha=0.7))
    ax.text(8.5, 1.2, 'Production', ha='center', fontsize=10, 
            bbox=dict(boxstyle='round', facecolor='#C8E6C9', alpha=0.7))
    
    # Legend
    legend_y = 0.3
    ax.text(1, legend_y, 'Stage Types:', fontsize=9, fontweight='bold')
    ax.text(2.5, legend_y, '■ Source Control', fontsize=8, color='#4CAF50')
    ax.text(4, legend_y, '■ Validation', fontsize=8, color='#2196F3')
    ax.text(5.5, legend_y, '■ Deployment', fontsize=8, color='#FF9800')
    ax.text(7, legend_y, '■ Testing', fontsize=8, color='#9C27B0')
    ax.text(8.5, legend_y, '■ Approval', fontsize=8, color='#F44336')
    
    plt.tight_layout()
    plt.savefig('docs/design/images/deployment_pipeline_diagram.png', dpi=300, bbox_inches='tight', 
                facecolor='white', edgecolor='none')
    print("✓ Generated: images/deployment_pipeline_diagram.png")
    plt.close()

def main():
    """Generate all design diagrams"""
    print("Generating design diagrams...")
    print("-" * 50)
    
    create_high_level_architecture()
    create_data_flow_diagram()
    create_security_diagram()
    create_deployment_pipeline_diagram()
    
    print("-" * 50)
    print("✓ All diagrams generated successfully!")
    print("\nGenerated files:")
    print("  - docs/design/architecture_overview.png")
    print("  - docs/design/data_flow_diagram.png")
    print("  - docs/design/security_rbac_diagram.png")
    print("  - docs/design/deployment_pipeline_diagram.png")
    print("\nThese diagrams can be embedded in SYSTEM_DESIGN.md")

if __name__ == "__main__":
    main()
