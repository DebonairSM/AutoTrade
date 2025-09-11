#!/usr/bin/env python3
"""
Grande News System - Quick Setup and Run
Get everything working in 5 minutes!
"""

import os
import sys
import subprocess
import json
from datetime import datetime

def check_python_version():
    """Check if Python version is compatible"""
    if sys.version_info < (3, 7):
        print("❌ Python 3.7+ required. Current version:", sys.version)
        return False
    print(f"✅ Python version: {sys.version}")
    return True

def install_requirements():
    """Install required packages"""
    print("📦 Installing requirements...")
    
    try:
        # Install basic requirements
        subprocess.check_call([sys.executable, "-m", "pip", "install", "requests"])
        print("✅ requests installed")
        
        # Try to install investpy (completely free)
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "investpy"])
            print("✅ investpy installed (completely free)")
        except:
            print("⚠️  investpy installation failed - will use simulated data")
        
        # Try to install yfinance (TradingView alternative)
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "yfinance"])
            print("✅ yfinance installed (TradingView alternative)")
        except:
            print("⚠️  yfinance installation failed - will use simulated data")
        
        return True
    except Exception as e:
        print(f"❌ Error installing requirements: {e}")
        return False

def setup_environment():
    """Setup environment variables"""
    print("🔧 Setting up environment...")
    
    # Check for NewsAPI key
    if not os.getenv('NEWSAPI_KEY'):
        print("💡 NEWSAPI_KEY not set")
        print("💡 Get FREE key at: https://newsapi.org/register")
        print("💡 No credit card required - 1000 requests/day FREE")
        
        # Ask user if they want to set it
        response = input("\nDo you want to set NewsAPI key now? (y/n): ").lower()
        if response == 'y':
            api_key = input("Enter your NewsAPI key: ").strip()
            if api_key:
                os.environ['NEWSAPI_KEY'] = api_key
                print("✅ NewsAPI key set!")
            else:
                print("⚠️  No key provided - will use simulated data")
        else:
            print("ℹ️  Will use simulated data for now")
    else:
        print("✅ NewsAPI key already set")
    
    return True

def run_quick_test():
    """Run a quick test of the system"""
    print("🧪 Running quick test...")
    
    try:
        # Import and run the quick start system
        from quick_start_free import QuickStartFreeNews
        
        system = QuickStartFreeNews()
        result = system.run()
        
        print("✅ Quick test completed successfully!")
        return result
    except Exception as e:
        print(f"❌ Quick test failed: {e}")
        return None

def show_upgrade_options():
    """Show upgrade options"""
    print("\n🚀 UPGRADE OPTIONS")
    print("=" * 30)
    
    print("\n1. FREE TIER (Current)")
    print("   Cost: $0.00/month")
    print("   Articles: 50/day")
    print("   Sources: NewsAPI Free, Investpy, TradingView Free")
    print("   Best for: Testing, small projects")
    
    print("\n2. NEWSAPI PRO")
    print("   Cost: $25.00/month")
    print("   Articles: 500/day")
    print("   Sources: NewsAPI Pro, Investpy, TradingView Free")
    print("   Best for: Medium projects, more articles")
    
    print("\n3. PREMIUM PACKAGE")
    print("   Cost: $99.00/month")
    print("   Articles: 2000/day")
    print("   Sources: All sources, custom feeds")
    print("   Best for: Large projects, production use")
    
    print("\n4. ENTERPRISE")
    print("   Cost: $299.00/month")
    print("   Articles: 10000/day")
    print("   Sources: All sources, custom APIs")
    print("   Best for: Enterprise, unlimited usage")

def main():
    """Main setup function"""
    print("🚀 GRANDE NEWS SYSTEM - QUICK SETUP")
    print("=" * 50)
    print("Get everything working in 5 minutes!")
    print()
    
    # Step 1: Check Python version
    if not check_python_version():
        return 1
    
    # Step 2: Install requirements
    if not install_requirements():
        print("❌ Failed to install requirements")
        return 1
    
    # Step 3: Setup environment
    if not setup_environment():
        print("❌ Failed to setup environment")
        return 1
    
    # Step 4: Run quick test
    print("\n" + "="*50)
    print("🧪 RUNNING QUICK TEST")
    print("="*50)
    
    result = run_quick_test()
    if not result:
        print("❌ Quick test failed")
        return 1
    
    # Step 5: Show upgrade options
    show_upgrade_options()
    
    # Step 6: Show next steps
    print("\n🎯 NEXT STEPS")
    print("=" * 15)
    print("1. Test the system with current setup")
    print("2. Get NewsAPI key for more articles (optional)")
    print("3. Run: python quick_start_free.py")
    print("4. Run: python upgrade_path.py (for upgrade analysis)")
    print("5. Integrate with your MT5 system")
    
    print("\n✅ SETUP COMPLETE!")
    print("=" * 20)
    print("Your Grande News System is ready to use!")
    print("Total cost so far: $0.00")
    
    return 0

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
