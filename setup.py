#!/usr/bin/env python3
"""
Enterprise AI Intelligence Platform Setup Script
Installs all required dependencies for the competition entry
"""

import subprocess
import sys
import os

def install_requirements():
    """Install all required packages"""
    
    print("🚀 Setting up Enterprise AI Intelligence Platform...")
    print("=" * 60)
    
    # Required packages
    packages = [
        'pandas>=1.3.0',
        'numpy>=1.21.0', 
        'google-cloud-bigquery>=3.0.0',
        'plotly>=5.0.0',
        'jupyter>=1.0.0',
        'ipywidgets>=7.6.0',
        'kaleido>=0.2.1'
    ]
    
    print("📦 Installing required packages...")
    for package in packages:
        print(f"   Installing {package}...")
        try:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', package])
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to install {package}: {e}")
            return False
    
    print("\n✅ All packages installed successfully!")
    print("\n🎯 Setup Complete! Ready for competition!")
    print("\n📋 Next Steps:")
    print("   1. Run: jupyter notebook Enterprise_AI_Intelligence_Platform.ipynb")
    print("   2. Execute all cells to see the AI intelligence in action")
    print("   3. Review the professional presentation materials")
    
    return True

if __name__ == "__main__":
    success = install_requirements()
    if not success:
        sys.exit(1)
    
    print("\n🏆 Enterprise AI Intelligence Platform is ready to win!")