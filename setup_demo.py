#!/usr/bin/env python3
"""
Enterprise Knowledge Intelligence Platform - Demo Setup Script

This script helps set up the demonstration environment and validates prerequisites.
"""

import os
import sys
import subprocess
import json
from pathlib import Path

def check_python_version():
    """Check if Python version is compatible"""
    if sys.version_info < (3, 7):
        print("❌ Python 3.7+ required. Current version:", sys.version)
        return False
    print(f"✅ Python version: {sys.version.split()[0]}")
    return True

def check_required_packages():
    """Check if required Python packages are installed"""
    required_packages = [
        'google-cloud-bigquery',
        'pandas',
        'numpy',
        'matplotlib',
        'seaborn',
        'jupyter'
    ]
    
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package.replace('-', '_'))
            print(f"✅ {package} installed")
        except ImportError:
            missing_packages.append(package)
            print(f"❌ {package} missing")
    
    if missing_packages:
        print(f"\n📦 Install missing packages with:")
        print(f"pip install {' '.join(missing_packages)}")
        return False
    
    return True

def check_gcloud_auth():
    """Check Google Cloud authentication"""
    try:
        result = subprocess.run(['gcloud', 'auth', 'list'], 
                              capture_output=True, text=True)
        if result.returncode == 0 and 'ACTIVE' in result.stdout:
            print("✅ Google Cloud authentication configured")
            return True
        else:
            print("❌ Google Cloud authentication not configured")
            print("Run: gcloud auth login")
            return False
    except FileNotFoundError:
        print("❌ Google Cloud SDK not installed")
        print("Install from: https://cloud.google.com/sdk/docs/install")
        return False

def get_project_config():
    """Get or set Google Cloud project configuration"""
    try:
        result = subprocess.run(['gcloud', 'config', 'get-value', 'project'], 
                              capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip():
            project_id = result.stdout.strip()
            print(f"✅ Current project: {project_id}")
            return project_id
        else:
            print("❌ No default project set")
            project_id = input("Enter your Google Cloud project ID: ")
            subprocess.run(['gcloud', 'config', 'set', 'project', project_id])
            return project_id
    except Exception as e:
        print(f"❌ Error getting project config: {e}")
        return None

def check_bigquery_access(project_id):
    """Check BigQuery access and permissions"""
    try:
        from google.cloud import bigquery
        client = bigquery.Client(project=project_id)
        
        # Test basic BigQuery access
        datasets = list(client.list_datasets())
        print(f"✅ BigQuery access confirmed ({len(datasets)} datasets)")
        
        # Check for AI/ML capabilities
        try:
            query = "SELECT 1 as test"
            job = client.query(query)
            job.result()
            print("✅ BigQuery query execution working")
        except Exception as e:
            print(f"⚠️  BigQuery query test failed: {e}")
            
        return True
        
    except Exception as e:
        print(f"❌ BigQuery access failed: {e}")
        print("Ensure BigQuery API is enabled and you have appropriate permissions")
        return False

def create_demo_config(project_id):
    """Create demo configuration file"""
    config = {
        "project_id": project_id,
        "dataset_id": "enterprise_knowledge_ai",
        "demo_mode": True,
        "use_simulated_data": True,
        "created_at": "2024-12-19"
    }
    
    with open('demo_config.json', 'w') as f:
        json.dump(config, f, indent=2)
    
    print("✅ Demo configuration created: demo_config.json")

def setup_jupyter_environment():
    """Set up Jupyter notebook environment"""
    try:
        # Check if Jupyter is installed
        result = subprocess.run(['jupyter', '--version'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ Jupyter notebook available")
            
            # Check if notebook exists
            if Path('enterprise_knowledge_ai_demo.ipynb').exists():
                print("✅ Demo notebook found")
                return True
            else:
                print("❌ Demo notebook not found")
                return False
        else:
            print("❌ Jupyter not installed")
            return False
    except FileNotFoundError:
        print("❌ Jupyter not found in PATH")
        return False

def main():
    """Main setup function"""
    print("🚀 Enterprise Knowledge Intelligence Platform - Demo Setup")
    print("=" * 60)
    
    # Check prerequisites
    checks = [
        ("Python Version", check_python_version),
        ("Required Packages", check_required_packages),
        ("Google Cloud Auth", check_gcloud_auth),
        ("Jupyter Environment", setup_jupyter_environment)
    ]
    
    all_passed = True
    for check_name, check_func in checks:
        print(f"\n🔍 Checking {check_name}...")
        if not check_func():
            all_passed = False
    
    # Get project configuration
    print(f"\n🔍 Checking Google Cloud Project...")
    project_id = get_project_config()
    if not project_id:
        all_passed = False
    
    # Check BigQuery access
    if project_id:
        print(f"\n🔍 Checking BigQuery Access...")
        if not check_bigquery_access(project_id):
            print("⚠️  BigQuery access issues detected - demo will use simulated data")
        
        create_demo_config(project_id)
    
    # Final status
    print("\n" + "=" * 60)
    if all_passed:
        print("🎉 Setup completed successfully!")
        print("\n📋 Next steps:")
        print("1. jupyter notebook enterprise_knowledge_ai_demo.ipynb")
        print("2. Follow the demo guide in DEMO_README.md")
        print("3. Execute cells sequentially for full demonstration")
    else:
        print("⚠️  Setup completed with warnings")
        print("Demo will work with simulated data where real services unavailable")
        print("\n📋 To start demo anyway:")
        print("jupyter notebook enterprise_knowledge_ai_demo.ipynb")
    
    print("\n🔗 Resources:")
    print("• Demo Guide: DEMO_README.md")
    print("• Configuration: demo_config.json")
    print("• Support: Check troubleshooting section in README")

if __name__ == "__main__":
    main()