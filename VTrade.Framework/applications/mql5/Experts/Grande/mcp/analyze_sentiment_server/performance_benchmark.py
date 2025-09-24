#!/usr/bin/env python3
"""
Performance Benchmark for Enhanced FinBERT Implementation
Tests accuracy, speed, and reliability against research standards.
"""

import json
import time
import statistics
from typing import List, Dict, Any
from dataclasses import dataclass
import os

# Import our enhanced analyzer
from finbert_calendar_analyzer import analyze_events, classify_finbert, build_event_text


@dataclass
class BenchmarkResult:
    """Results from performance benchmark."""
    test_name: str
    accuracy: float
    processing_time_ms: float
    confidence_score: float
    signal_consistency: float
    surprise_accuracy: float
    total_events: int
    high_confidence_count: int
    success: bool
    error_message: str = ""


class FinBERTBenchmark:
    """Comprehensive benchmark for FinBERT implementation."""
    
    def __init__(self):
        self.results: List[BenchmarkResult] = []
        
    def load_test_data(self, filename: str) -> List[Dict[str, Any]]:
        """Load test economic events data."""
        try:
            with open(filename, 'r') as f:
                data = json.load(f)
                return data.get('events', [])
        except Exception as e:
            print(f"Error loading test data: {e}")
            return []
    
    def run_accuracy_test(self, events: List[Dict[str, Any]], expected_signals: List[str]) -> BenchmarkResult:
        """Test accuracy against known good signals."""
        start_time = time.time()
        
        try:
            result = analyze_events(events)
            processing_time = (time.time() - start_time) * 1000
            
            # Calculate accuracy based on expected vs actual signals
            actual_signal = result.get('signal', 'NEUTRAL')
            accuracy = 1.0 if actual_signal in expected_signals else 0.0
            
            # Extract metrics
            metrics = result.get('metrics', {})
            confidence = metrics.get('average_confidence', 0.0)
            consistency = metrics.get('signal_consistency', 0.0)
            surprise_acc = metrics.get('surprise_accuracy', 0.0)
            event_count = metrics.get('total_events', 0)
            high_conf_count = metrics.get('high_confidence_predictions', 0)
            
            return BenchmarkResult(
                test_name="Accuracy Test",
                accuracy=accuracy,
                processing_time_ms=processing_time,
                confidence_score=confidence,
                signal_consistency=consistency,
                surprise_accuracy=surprise_acc,
                total_events=event_count,
                high_confidence_count=high_conf_count,
                success=True
            )
            
        except Exception as e:
            return BenchmarkResult(
                test_name="Accuracy Test",
                accuracy=0.0,
                processing_time_ms=0.0,
                confidence_score=0.0,
                signal_consistency=0.0,
                surprise_accuracy=0.0,
                total_events=0,
                high_confidence_count=0,
                success=False,
                error_message=str(e)
            )
    
    def run_speed_test(self, events: List[Dict[str, Any]], iterations: int = 10) -> BenchmarkResult:
        """Test processing speed with multiple iterations."""
        times = []
        
        try:
            for i in range(iterations):
                start_time = time.time()
                result = analyze_events(events)
                processing_time = (time.time() - start_time) * 1000
                times.append(processing_time)
            
            avg_time = statistics.mean(times)
            std_dev = statistics.stdev(times) if len(times) > 1 else 0.0
            
            # Check if processing time is acceptable (< 500ms)
            success = avg_time < 500.0
            
            return BenchmarkResult(
                test_name="Speed Test",
                accuracy=1.0 if success else 0.0,
                processing_time_ms=avg_time,
                confidence_score=1.0 - (std_dev / avg_time) if avg_time > 0 else 0.0,
                signal_consistency=0.0,
                surprise_accuracy=0.0,
                total_events=len(events),
                high_confidence_count=0,
                success=success,
                error_message=f"Std Dev: {std_dev:.2f}ms" if not success else ""
            )
            
        except Exception as e:
            return BenchmarkResult(
                test_name="Speed Test",
                accuracy=0.0,
                processing_time_ms=0.0,
                confidence_score=0.0,
                signal_consistency=0.0,
                surprise_accuracy=0.0,
                total_events=0,
                high_confidence_count=0,
                success=False,
                error_message=str(e)
            )
    
    def run_reliability_test(self, events: List[Dict[str, Any]], iterations: int = 5) -> BenchmarkResult:
        """Test consistency across multiple runs."""
        signals = []
        confidences = []
        
        try:
            for i in range(iterations):
                result = analyze_events(events)
                signals.append(result.get('signal', 'NEUTRAL'))
                confidences.append(result.get('confidence', 0.0))
            
            # Calculate consistency (same signal across runs)
            unique_signals = len(set(signals))
            consistency = 1.0 / unique_signals if unique_signals > 0 else 0.0
            
            # Calculate confidence stability
            avg_confidence = statistics.mean(confidences)
            confidence_std = statistics.stdev(confidences) if len(confidences) > 1 else 0.0
            confidence_stability = 1.0 - (confidence_std / avg_confidence) if avg_confidence > 0 else 0.0
            
            # Success if consistency > 0.8 and confidence stability > 0.9
            success = consistency > 0.8 and confidence_stability > 0.9
            
            return BenchmarkResult(
                test_name="Reliability Test",
                accuracy=consistency,
                processing_time_ms=0.0,
                confidence_score=confidence_stability,
                signal_consistency=consistency,
                surprise_accuracy=0.0,
                total_events=len(events),
                high_confidence_count=0,
                success=success,
                error_message=f"Signals: {signals}, Confidence Std: {confidence_std:.3f}" if not success else ""
            )
            
        except Exception as e:
            return BenchmarkResult(
                test_name="Reliability Test",
                accuracy=0.0,
                processing_time_ms=0.0,
                confidence_score=0.0,
                signal_consistency=0.0,
                surprise_accuracy=0.0,
                total_events=0,
                high_confidence_count=0,
                success=False,
                error_message=str(e)
            )
    
    def run_comprehensive_test(self, events: List[Dict[str, Any]]) -> BenchmarkResult:
        """Run comprehensive test combining all metrics."""
        try:
            result = analyze_events(events)
            metrics = result.get('metrics', {})
            
            # Calculate overall score based on multiple factors
            accuracy = metrics.get('surprise_accuracy', 0.0)
            consistency = metrics.get('signal_consistency', 0.0)
            confidence = metrics.get('average_confidence', 0.0)
            processing_time = metrics.get('processing_time_ms', 1000.0)
            
            # Weighted score
            overall_score = (
                accuracy * 0.3 +
                consistency * 0.3 +
                confidence * 0.2 +
                min(1.0, 500.0 / processing_time) * 0.2
            )
            
            success = overall_score > 0.7
            
            return BenchmarkResult(
                test_name="Comprehensive Test",
                accuracy=overall_score,
                processing_time_ms=processing_time,
                confidence_score=confidence,
                signal_consistency=consistency,
                surprise_accuracy=accuracy,
                total_events=metrics.get('total_events', 0),
                high_confidence_count=metrics.get('high_confidence_predictions', 0),
                success=success,
                error_message=f"Overall Score: {overall_score:.3f}" if not success else ""
            )
            
        except Exception as e:
            return BenchmarkResult(
                test_name="Comprehensive Test",
                accuracy=0.0,
                processing_time_ms=0.0,
                confidence_score=0.0,
                signal_consistency=0.0,
                surprise_accuracy=0.0,
                total_events=0,
                high_confidence_count=0,
                success=False,
                error_message=str(e)
            )
    
    def run_all_tests(self, test_data_file: str = "test_sample_events.json") -> Dict[str, Any]:
        """Run all benchmark tests."""
        print("=== FINBERT PERFORMANCE BENCHMARK ===")
        
        # Load test data
        events = self.load_test_data(test_data_file)
        if not events:
            print("ERROR: No test data available")
            return {"error": "No test data"}
        
        print(f"Running tests with {len(events)} economic events...")
        
        # Run all tests
        self.results = []
        
        # Accuracy test
        print("1. Running accuracy test...")
        accuracy_result = self.run_accuracy_test(events, ["BUY", "STRONG_BUY"])
        self.results.append(accuracy_result)
        
        # Speed test
        print("2. Running speed test...")
        speed_result = self.run_speed_test(events)
        self.results.append(speed_result)
        
        # Reliability test
        print("3. Running reliability test...")
        reliability_result = self.run_reliability_test(events)
        self.results.append(reliability_result)
        
        # Comprehensive test
        print("4. Running comprehensive test...")
        comprehensive_result = self.run_comprehensive_test(events)
        self.results.append(comprehensive_result)
        
        # Generate summary
        return self.generate_summary()
    
    def generate_summary(self) -> Dict[str, Any]:
        """Generate benchmark summary."""
        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results if r.success)
        
        avg_accuracy = statistics.mean([r.accuracy for r in self.results])
        avg_processing_time = statistics.mean([r.processing_time_ms for r in self.results if r.processing_time_ms > 0])
        avg_confidence = statistics.mean([r.confidence_score for r in self.results])
        
        summary = {
            "benchmark_summary": {
                "total_tests": total_tests,
                "passed_tests": passed_tests,
                "success_rate": passed_tests / total_tests if total_tests > 0 else 0.0,
                "average_accuracy": avg_accuracy,
                "average_processing_time_ms": avg_processing_time,
                "average_confidence": avg_confidence,
                "overall_grade": self.calculate_grade(passed_tests / total_tests, avg_accuracy)
            },
            "test_results": [
                {
                    "test_name": r.test_name,
                    "passed": r.success,
                    "accuracy": r.accuracy,
                    "processing_time_ms": r.processing_time_ms,
                    "confidence": r.confidence_score,
                    "consistency": r.signal_consistency,
                    "error": r.error_message
                }
                for r in self.results
            ],
            "research_standards_compliance": {
                "accuracy_threshold": ">= 0.8",
                "processing_time_threshold": "<= 500ms",
                "confidence_threshold": ">= 0.7",
                "consistency_threshold": ">= 0.8"
            }
        }
        
        # Print summary
        print("\n=== BENCHMARK RESULTS ===")
        print(f"Tests Passed: {passed_tests}/{total_tests}")
        print(f"Success Rate: {passed_tests/total_tests*100:.1f}%")
        print(f"Average Accuracy: {avg_accuracy:.3f}")
        print(f"Average Processing Time: {avg_processing_time:.1f}ms")
        print(f"Average Confidence: {avg_confidence:.3f}")
        print(f"Overall Grade: {summary['benchmark_summary']['overall_grade']}")
        
        return summary
    
    def calculate_grade(self, success_rate: float, accuracy: float) -> str:
        """Calculate overall grade based on performance."""
        if success_rate >= 0.9 and accuracy >= 0.8:
            return "A+ (Excellent)"
        elif success_rate >= 0.8 and accuracy >= 0.7:
            return "A (Very Good)"
        elif success_rate >= 0.7 and accuracy >= 0.6:
            return "B (Good)"
        elif success_rate >= 0.6 and accuracy >= 0.5:
            return "C (Acceptable)"
        else:
            return "D (Needs Improvement)"


def main():
    """Run the performance benchmark."""
    benchmark = FinBERTBenchmark()
    results = benchmark.run_all_tests()
    
    # Save results
    with open("benchmark_results.json", "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"\nBenchmark results saved to: benchmark_results.json")
    return results


if __name__ == "__main__":
    main()
