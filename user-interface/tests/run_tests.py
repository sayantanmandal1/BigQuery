#!/usr/bin/env python3
"""
Test Runner for Enterprise Knowledge Intelligence UI Integration Tests
Runs comprehensive tests for API endpoints, dashboard, analyst workbench, and mobile interface
"""

import os
import sys
import subprocess
import argparse
import json
from datetime import datetime

def run_command(command, description):
    """Run a command and return the result"""
    print(f"\n{'='*60}")
    print(f"Running: {description}")
    print(f"Command: {command}")
    print(f"{'='*60}")
    
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )
        
        if result.stdout:
            print("STDOUT:")
            print(result.stdout)
        
        if result.stderr:
            print("STDERR:")
            print(result.stderr)
        
        return result.returncode == 0, result.stdout, result.stderr
    
    except subprocess.TimeoutExpired:
        print("ERROR: Command timed out after 5 minutes")
        return False, "", "Command timed out"
    except Exception as e:
        print(f"ERROR: Failed to run command: {e}")
        return False, "", str(e)

def setup_test_environment():
    """Set up the test environment"""
    print("Setting up test environment...")
    
    # Install test dependencies
    success, stdout, stderr = run_command(
        "pip install -r user-interface/tests/requirements.txt",
        "Installing test dependencies"
    )
    
    if not success:
        print("Failed to install test dependencies")
        return False
    
    # Check if Chrome/Chromium is available for Selenium tests
    chrome_available = False
    for chrome_cmd in ["google-chrome", "chromium-browser", "chrome"]:
        success, _, _ = run_command(f"which {chrome_cmd}", f"Checking for {chrome_cmd}")
        if success:
            chrome_available = True
            break
    
    if not chrome_available:
        print("WARNING: Chrome/Chromium not found. UI tests will be skipped.")
        print("To run UI tests, install Chrome or Chromium browser.")
    
    return True

def run_api_tests():
    """Run API integration tests"""
    print("\n" + "="*60)
    print("RUNNING API INTEGRATION TESTS")
    print("="*60)
    
    # Start mock API server for testing (in a real scenario)
    # For this demo, we'll run the tests with mocked responses
    
    success, stdout, stderr = run_command(
        "python -m pytest user-interface/tests/integration_tests.py::APIIntegrationTests -v --tb=short",
        "API Integration Tests"
    )
    
    return success, stdout, stderr

def run_ui_tests():
    """Run UI integration tests"""
    print("\n" + "="*60)
    print("RUNNING UI INTEGRATION TESTS")
    print("="*60)
    
    test_classes = [
        "DashboardUITests",
        "AnalystWorkbenchTests", 
        "MobileInterfaceTests"
    ]
    
    results = {}
    
    for test_class in test_classes:
        print(f"\nRunning {test_class}...")
        success, stdout, stderr = run_command(
            f"python -m pytest user-interface/tests/integration_tests.py::{test_class} -v --tb=short",
            f"{test_class} Tests"
        )
        results[test_class] = {
            'success': success,
            'stdout': stdout,
            'stderr': stderr
        }
    
    return results

def run_performance_tests():
    """Run performance tests"""
    print("\n" + "="*60)
    print("RUNNING PERFORMANCE TESTS")
    print("="*60)
    
    success, stdout, stderr = run_command(
        "python -m pytest user-interface/tests/integration_tests.py::PerformanceTests -v --tb=short",
        "Performance Tests"
    )
    
    return success, stdout, stderr

def run_accessibility_tests():
    """Run accessibility tests"""
    print("\n" + "="*60)
    print("RUNNING ACCESSIBILITY TESTS")
    print("="*60)
    
    success, stdout, stderr = run_command(
        "python -m pytest user-interface/tests/integration_tests.py::AccessibilityTests -v --tb=short",
        "Accessibility Tests"
    )
    
    return success, stdout, stderr

def run_all_tests():
    """Run all integration tests"""
    print("\n" + "="*60)
    print("RUNNING ALL INTEGRATION TESTS")
    print("="*60)
    
    success, stdout, stderr = run_command(
        "python -m pytest user-interface/tests/integration_tests.py -v --tb=short --html=test_report.html --self-contained-html",
        "All Integration Tests"
    )
    
    return success, stdout, stderr

def generate_test_report(results):
    """Generate a comprehensive test report"""
    report = {
        'timestamp': datetime.now().isoformat(),
        'summary': {
            'total_test_suites': 0,
            'passed_test_suites': 0,
            'failed_test_suites': 0,
            'overall_success': True
        },
        'results': results
    }
    
    # Calculate summary statistics
    for test_name, result in results.items():
        report['summary']['total_test_suites'] += 1
        if isinstance(result, dict) and result.get('success'):
            report['summary']['passed_test_suites'] += 1
        elif isinstance(result, bool) and result:
            report['summary']['passed_test_suites'] += 1
        else:
            report['summary']['failed_test_suites'] += 1
            report['summary']['overall_success'] = False
    
    # Write report to file
    report_file = f"test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_file, 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"\n{'='*60}")
    print("TEST EXECUTION SUMMARY")
    print(f"{'='*60}")
    print(f"Total test suites: {report['summary']['total_test_suites']}")
    print(f"Passed: {report['summary']['passed_test_suites']}")
    print(f"Failed: {report['summary']['failed_test_suites']}")
    print(f"Overall success: {report['summary']['overall_success']}")
    print(f"Report saved to: {report_file}")
    
    return report

def main():
    """Main test runner function"""
    parser = argparse.ArgumentParser(description='Run Enterprise Knowledge Intelligence UI Integration Tests')
    parser.add_argument('--test-type', choices=['api', 'ui', 'performance', 'accessibility', 'all'], 
                       default='all', help='Type of tests to run')
    parser.add_argument('--skip-setup', action='store_true', help='Skip test environment setup')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    print("Enterprise Knowledge Intelligence UI Integration Test Runner")
    print("="*60)
    print(f"Test type: {args.test_type}")
    print(f"Timestamp: {datetime.now().isoformat()}")
    
    # Setup test environment
    if not args.skip_setup:
        if not setup_test_environment():
            print("Failed to set up test environment")
            sys.exit(1)
    
    results = {}
    
    try:
        if args.test_type == 'api' or args.test_type == 'all':
            success, stdout, stderr = run_api_tests()
            results['api_tests'] = {
                'success': success,
                'stdout': stdout,
                'stderr': stderr
            }
        
        if args.test_type == 'ui' or args.test_type == 'all':
            ui_results = run_ui_tests()
            results.update(ui_results)
        
        if args.test_type == 'performance' or args.test_type == 'all':
            success, stdout, stderr = run_performance_tests()
            results['performance_tests'] = {
                'success': success,
                'stdout': stdout,
                'stderr': stderr
            }
        
        if args.test_type == 'accessibility' or args.test_type == 'all':
            success, stdout, stderr = run_accessibility_tests()
            results['accessibility_tests'] = {
                'success': success,
                'stdout': stdout,
                'stderr': stderr
            }
        
        if args.test_type == 'all':
            # Also run all tests together for comprehensive report
            success, stdout, stderr = run_all_tests()
            results['comprehensive_test'] = {
                'success': success,
                'stdout': stdout,
                'stderr': stderr
            }
    
    except KeyboardInterrupt:
        print("\nTest execution interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nUnexpected error during test execution: {e}")
        sys.exit(1)
    
    # Generate and display report
    report = generate_test_report(results)
    
    # Exit with appropriate code
    if report['summary']['overall_success']:
        print("\n✅ All tests passed successfully!")
        sys.exit(0)
    else:
        print("\n❌ Some tests failed. Check the report for details.")
        sys.exit(1)

if __name__ == '__main__':
    main()