#!/usr/bin/env python3
"""
Integration Test for Grande Enhanced FinBERT System
Tests complete pipeline from economic events to MQL5-ready output.
"""

import json
import os
import sys
import time
from typing import Dict, Any

# Add current directory to path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from finbert_calendar_analyzer import analyze_events
from main import analyze_calendar_events


class GrandeIntegrationTest:
    """Comprehensive integration test for the entire Grande FinBERT system."""
    
    def __init__(self):
        self.test_results = {}
        self.sample_events = [
            {
                "time_utc": "2025-01-15 14:30:00",
                "currency": "USD",
                "name": "Consumer Price Index (CPI)",
                "actual": 3.2,
                "forecast": 3.0,
                "previous": 2.8,
                "impact": "High"
            },
            {
                "time_utc": "2025-01-15 16:00:00", 
                "currency": "EUR",
                "name": "Unemployment Rate",
                "actual": 6.8,
                "forecast": 7.2,
                "previous": 7.5,
                "impact": "Medium"
            },
            {
                "time_utc": "2025-01-16 09:30:00",
                "currency": "GBP", 
                "name": "Retail Sales",
                "actual": 2.1,
                "forecast": 1.8,
                "previous": 1.5,
                "impact": "Critical"
            }
        ]
    
    def test_finbert_analyzer(self) -> Dict[str, Any]:
        """Test the standalone FinBERT analyzer."""
        print("Testing FinBERT Calendar Analyzer...")
        
        try:
            result = analyze_events(self.sample_events)
            
            # Validate required fields
            required_fields = ["signal", "score", "confidence", "reasoning", "event_count", "per_event", "analyzer", "metrics"]
            missing_fields = [field for field in required_fields if field not in result]
            
            if missing_fields:
                return {
                    "test": "finbert_analyzer",
                    "status": "FAILED",
                    "error": f"Missing fields: {missing_fields}",
                    "result": result
                }
            
            # Validate signal format
            valid_signals = ["STRONG_BUY", "BUY", "NEUTRAL", "SELL", "STRONG_SELL"]
            if result["signal"] not in valid_signals:
                return {
                    "test": "finbert_analyzer",
                    "status": "FAILED",
                    "error": f"Invalid signal: {result['signal']}",
                    "result": result
                }
            
            # Validate score range
            if not (-1.0 <= result["score"] <= 1.0):
                return {
                    "test": "finbert_analyzer",
                    "status": "FAILED",
                    "error": f"Score out of range: {result['score']}",
                    "result": result
                }
            
            # Validate confidence range
            if not (0.0 <= result["confidence"] <= 1.0):
                return {
                    "test": "finbert_analyzer",
                    "status": "FAILED",
                    "error": f"Confidence out of range: {result['confidence']}",
                    "result": result
                }
            
            # Validate metrics
            metrics = result.get("metrics", {})
            required_metrics = ["total_events", "high_confidence_predictions", "average_confidence", "surprise_accuracy", "signal_consistency", "processing_time_ms"]
            missing_metrics = [metric for metric in required_metrics if metric not in metrics]
            
            if missing_metrics:
                return {
                    "test": "finbert_analyzer",
                    "status": "FAILED",
                    "error": f"Missing metrics: {missing_metrics}",
                    "result": result
                }
            
            return {
                "test": "finbert_analyzer",
                "status": "PASSED",
                "signal": result["signal"],
                "score": result["score"],
                "confidence": result["confidence"],
                "event_count": result["event_count"],
                "processing_time_ms": metrics.get("processing_time_ms", 0),
                "surprise_accuracy": metrics.get("surprise_accuracy", 0),
                "signal_consistency": metrics.get("signal_consistency", 0)
            }
            
        except Exception as e:
            return {
                "test": "finbert_analyzer",
                "status": "FAILED",
                "error": str(e),
                "result": None
            }
    
    def test_mcp_server(self) -> Dict[str, Any]:
        """Test the MCP server integration."""
        print("Testing MCP Server Integration...")
        
        try:
            # Create a mock context for testing
            class MockContext:
                async def error(self, message):
                    print(f"Mock Context Error: {message}")
            
            # Test calendar events analysis through MCP server
            import asyncio
            mock_ctx = MockContext()
            result = asyncio.run(analyze_calendar_events(self.sample_events, mock_ctx))
            
            # Validate MCP server response format
            required_fields = ["signal", "score", "confidence", "reasoning", "event_count", "per_event", "analyzer"]
            missing_fields = [field for field in required_fields if field not in result]
            
            if missing_fields:
                return {
                    "test": "mcp_server",
                    "status": "FAILED",
                    "error": f"Missing fields: {missing_fields}",
                    "result": result
                }
            
            return {
                "test": "mcp_server",
                "status": "PASSED",
                "signal": result["signal"],
                "score": result["score"],
                "confidence": result["confidence"],
                "analyzer": result["analyzer"]
            }
            
        except Exception as e:
            return {
                "test": "mcp_server",
                "status": "FAILED",
                "error": str(e),
                "result": None
            }
    
    def test_mql5_compatibility(self) -> Dict[str, Any]:
        """Test MQL5 compatibility by validating JSON format."""
        print("Testing MQL5 Compatibility...")
        
        try:
            # Generate analysis result
            result = analyze_events(self.sample_events)
            
            # Validate JSON serialization (MQL5 compatibility)
            json_str = json.dumps(result, indent=2)
            parsed_result = json.loads(json_str)
            
            if parsed_result != result:
                return {
                    "test": "mql5_compatibility",
                    "status": "FAILED",
                    "error": "JSON serialization/deserialization mismatch",
                    "result": None
                }
            
            # Validate MQL5 parsing requirements
            # Check that all numeric fields are properly formatted
            numeric_fields = ["score", "confidence", "event_count"]
            for field in numeric_fields:
                if field in result and not isinstance(result[field], (int, float)):
                    return {
                        "test": "mql5_compatibility",
                        "status": "FAILED",
                        "error": f"Non-numeric value in {field}: {result[field]}",
                        "result": None
                    }
            
            # Check per_event structure
            per_events = result.get("per_event", [])
            if per_events:
                first_event = per_events[0]
                required_event_fields = ["name", "currency", "impact", "weight", "finbert_score", "finbert_confidence", "adjusted_score"]
                missing_event_fields = [field for field in required_event_fields if field not in first_event]
                
                if missing_event_fields:
                    return {
                        "test": "mql5_compatibility",
                        "status": "FAILED",
                        "error": f"Missing event fields: {missing_event_fields}",
                        "result": None
                    }
            
            return {
                "test": "mcp_server",
                "status": "PASSED",
                "json_size_bytes": len(json_str),
                "event_count": len(per_events),
                "has_metrics": "metrics" in result,
                "has_research_validation": "research_validation" in result
            }
            
        except Exception as e:
            return {
                "test": "mql5_compatibility",
                "status": "FAILED",
                "error": str(e),
                "result": None
            }
    
    def test_performance_requirements(self) -> Dict[str, Any]:
        """Test performance requirements for live trading."""
        print("Testing Performance Requirements...")
        
        try:
            # Test processing time
            start_time = time.time()
            result = analyze_events(self.sample_events)
            processing_time = (time.time() - start_time) * 1000
            
            metrics = result.get("metrics", {})
            reported_time = metrics.get("processing_time_ms", 0)
            
            # Performance requirements
            max_processing_time = 500.0  # 500ms maximum
            min_confidence = 0.5         # Minimum confidence
            min_consistency = 0.7        # Minimum signal consistency
            
            performance_issues = []
            
            if processing_time > max_processing_time:
                performance_issues.append(f"Processing time too slow: {processing_time:.1f}ms > {max_processing_time}ms")
            
            if result["confidence"] < min_confidence:
                performance_issues.append(f"Confidence too low: {result['confidence']:.3f} < {min_confidence}")
            
            consistency = metrics.get("signal_consistency", 0)
            if consistency < min_consistency:
                performance_issues.append(f"Signal consistency too low: {consistency:.3f} < {min_consistency}")
            
            if performance_issues:
                return {
                    "test": "performance_requirements",
                    "status": "FAILED",
                    "errors": performance_issues,
                    "processing_time_ms": processing_time,
                    "reported_time_ms": reported_time,
                    "confidence": result["confidence"],
                    "consistency": consistency
                }
            
            return {
                "test": "performance_requirements",
                "status": "PASSED",
                "processing_time_ms": processing_time,
                "reported_time_ms": reported_time,
                "confidence": result["confidence"],
                "consistency": consistency,
                "performance_grade": self.calculate_performance_grade(processing_time, result["confidence"], consistency)
            }
            
        except Exception as e:
            return {
                "test": "performance_requirements",
                "status": "FAILED",
                "error": str(e),
                "result": None
            }
    
    def calculate_performance_grade(self, processing_time: float, confidence: float, consistency: float) -> str:
        """Calculate performance grade."""
        if processing_time < 100 and confidence > 0.8 and consistency > 0.9:
            return "A+ (Excellent)"
        elif processing_time < 200 and confidence > 0.7 and consistency > 0.8:
            return "A (Very Good)"
        elif processing_time < 300 and confidence > 0.6 and consistency > 0.7:
            return "B (Good)"
        elif processing_time < 500 and confidence > 0.5 and consistency > 0.6:
            return "C (Acceptable)"
        else:
            return "D (Needs Improvement)"
    
    def run_all_tests(self) -> Dict[str, Any]:
        """Run all integration tests."""
        print("=== GRANDE FINBERT INTEGRATION TEST ===")
        print(f"Testing with {len(self.sample_events)} economic events...")
        
        # Run all tests
        tests = [
            self.test_finbert_analyzer,
            self.test_mcp_server,
            self.test_mql5_compatibility,
            self.test_performance_requirements
        ]
        
        results = []
        for test_func in tests:
            result = test_func()
            results.append(result)
            status_emoji = "✅" if result["status"] == "PASSED" else "❌"
            print(f"{status_emoji} {result['test']}: {result['status']}")
            if result["status"] == "FAILED":
                print(f"   Error: {result.get('error', result.get('errors', 'Unknown error'))}")
        
        # Calculate summary
        total_tests = len(results)
        passed_tests = sum(1 for r in results if r["status"] == "PASSED")
        success_rate = passed_tests / total_tests * 100
        
        summary = {
            "integration_summary": {
                "total_tests": total_tests,
                "passed_tests": passed_tests,
                "success_rate": success_rate,
                "overall_status": "PASSED" if passed_tests == total_tests else "FAILED"
            },
            "test_results": results,
            "system_ready": passed_tests == total_tests,
            "deployment_grade": self.calculate_deployment_grade(success_rate)
        }
        
        # Print summary
        print(f"\n=== INTEGRATION TEST SUMMARY ===")
        print(f"Tests Passed: {passed_tests}/{total_tests}")
        print(f"Success Rate: {success_rate:.1f}%")
        print(f"Overall Status: {summary['integration_summary']['overall_status']}")
        print(f"Deployment Grade: {summary['deployment_grade']}")
        print(f"System Ready: {'YES' if summary['system_ready'] else 'NO'}")
        
        return summary
    
    def calculate_deployment_grade(self, success_rate: float) -> str:
        """Calculate deployment readiness grade."""
        if success_rate >= 100:
            return "A+ (Production Ready)"
        elif success_rate >= 90:
            return "A (Near Production Ready)"
        elif success_rate >= 80:
            return "B (Testing Required)"
        elif success_rate >= 70:
            return "C (Development Only)"
        else:
            return "D (Not Ready)"


def main():
    """Run the integration test."""
    test = GrandeIntegrationTest()
    results = test.run_all_tests()
    
    # Save results
    with open("integration_test_results.json", "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"\nIntegration test results saved to: integration_test_results.json")
    
    # Exit with appropriate code
    if results["system_ready"]:
        print("🎉 Grande FinBERT system is ready for deployment!")
        return 0
    else:
        print("⚠️  Grande FinBERT system needs attention before deployment.")
        return 1


if __name__ == "__main__":
    exit(main())
