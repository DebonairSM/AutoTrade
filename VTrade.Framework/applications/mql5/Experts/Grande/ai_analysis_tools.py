#!/usr/bin/env python3
"""
Grande Trading System - AI Analysis Tools
Machine learning analysis and model training for trading data
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split, cross_val_score, GridSearchCV
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.linear_model import LogisticRegression, LinearRegression
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score, mean_squared_error
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.cluster import KMeans
from sklearn.decomposition import PCA
import xgboost as xgb
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.optimizers import Adam
import warnings
warnings.filterwarnings('ignore')

class GrandeAIAnalyzer:
    """AI analysis tools for Grande Trading System data"""
    
    def __init__(self, data_dir: str = "ai_data_export"):
        """
        Initialize the AI analyzer
        
        Args:
            data_dir: Directory containing exported CSV files
        """
        self.data_dir = data_dir
        self.training_data = None
        self.performance_data = None
        self.regime_data = None
        self.scaler = StandardScaler()
        self.label_encoders = {}
    
    def load_data(self, symbol: str = "EURUSD"):
        """
        Load all data files for the given symbol
        
        Args:
            symbol: Trading symbol
        """
        import glob
        import os
        
        # Find the most recent files for the symbol
        pattern = os.path.join(self.data_dir, f"{symbol}_*_*.csv")
        files = glob.glob(pattern)
        
        if not files:
            raise FileNotFoundError(f"No data files found for symbol {symbol}")
        
        # Load different data types
        for file in files:
            if 'training_data' in file:
                self.training_data = pd.read_csv(file)
                print(f"Loaded training data: {len(self.training_data)} records")
            elif 'performance_analysis' in file:
                self.performance_data = pd.read_csv(file)
                print(f"Loaded performance data: {len(self.performance_data)} records")
            elif 'regime_analysis' in file:
                self.regime_data = pd.read_csv(file)
                print(f"Loaded regime data: {len(self.regime_data)} records")
    
    def prepare_training_features(self) -> Tuple[pd.DataFrame, pd.Series]:
        """
        Prepare features and target for machine learning
        
        Returns:
            Tuple of (features, target)
        """
        if self.training_data is None:
            raise ValueError("Training data not loaded")
        
        df = self.training_data.copy()
        
        # Create target variable (profitable trade)
        df['is_profitable'] = df['outcome'].apply(lambda x: 1 if x == 'PROFIT' else 0 if x == 'LOSS' else None)
        
        # Remove rows without target
        df = df.dropna(subset=['is_profitable'])
        
        # Select features
        feature_columns = [
            'atr', 'adx_h1', 'adx_h4', 'adx_d1', 'rsi_current', 'rsi_h4', 'rsi_d1',
            'ema_20', 'ema_50', 'ema_200', 'stoch_k', 'stoch_d', 'volume'
        ]
        
        # Add regime features
        regime_mapping = {'TREND_BULL': 1, 'TREND_BEAR': -1, 'RANGING': 0, 'BREAKOUT_SETUP': 2}
        df['regime_numeric'] = df['regime'].map(regime_mapping).fillna(0)
        feature_columns.append('regime_numeric')
        
        # Add sentiment features
        sentiment_mapping = {'STRONG_BUY': 1, 'BUY': 0.5, 'NEUTRAL': 0, 'SELL': -0.5, 'STRONG_SELL': -1}
        df['sentiment_numeric'] = df['sentiment_signal'].map(sentiment_mapping).fillna(0)
        feature_columns.append('sentiment_numeric')
        
        # Create technical indicators
        df['price_change'] = df['close_price'] - df['open_price']
        df['price_range'] = df['high_price'] - df['low_price']
        df['rsi_overbought'] = (df['rsi_current'] > 70).astype(int)
        df['rsi_oversold'] = (df['rsi_current'] < 30).astype(int)
        df['ema_trend'] = np.where(df['ema_20'] > df['ema_50'], 1, -1)
        
        feature_columns.extend(['price_change', 'price_range', 'rsi_overbought', 'rsi_oversold', 'ema_trend'])
        
        # Prepare features and target
        X = df[feature_columns].fillna(0)
        y = df['is_profitable']
        
        return X, y
    
    def train_signal_classifier(self) -> dict:
        """
        Train a classifier to predict profitable trades
        
        Returns:
            Dictionary with model performance metrics
        """
        X, y = self.prepare_training_features()
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        # Train Random Forest
        rf_model = RandomForestClassifier(n_estimators=100, random_state=42)
        rf_model.fit(X_train_scaled, y_train)
        
        # Predictions
        y_pred = rf_model.predict(X_test_scaled)
        y_pred_proba = rf_model.predict_proba(X_test_scaled)[:, 1]
        
        # Performance metrics
        accuracy = accuracy_score(y_test, y_pred)
        cv_scores = cross_val_score(rf_model, X_train_scaled, y_train, cv=5)
        
        # Feature importance
        feature_importance = pd.DataFrame({
            'feature': X.columns,
            'importance': rf_model.feature_importances_
        }).sort_values('importance', ascending=False)
        
        results = {
            'model': rf_model,
            'accuracy': accuracy,
            'cv_mean': cv_scores.mean(),
            'cv_std': cv_scores.std(),
            'feature_importance': feature_importance,
            'classification_report': classification_report(y_test, y_pred),
            'confusion_matrix': confusion_matrix(y_test, y_pred)
        }
        
        print(f"Signal Classifier Performance:")
        print(f"Accuracy: {accuracy:.3f}")
        print(f"CV Score: {cv_scores.mean():.3f} (+/- {cv_scores.std() * 2:.3f})")
        print("\nTop 10 Most Important Features:")
        print(feature_importance.head(10))
        
        return results
    
    def train_price_predictor(self) -> dict:
        """
        Train a regressor to predict price movements
        
        Returns:
            Dictionary with model performance metrics
        """
        if self.training_data is None:
            raise ValueError("Training data not loaded")
        
        df = self.training_data.copy()
        
        # Create target (next bar price change)
        df['next_price_change'] = df['close_price'].shift(-1) - df['close_price']
        df = df.dropna(subset=['next_price_change'])
        
        # Select features
        feature_columns = [
            'atr', 'adx_h1', 'adx_h4', 'adx_d1', 'rsi_current', 'rsi_h4', 'rsi_d1',
            'ema_20', 'ema_50', 'ema_200', 'stoch_k', 'stoch_d', 'volume',
            'open_price', 'high_price', 'low_price', 'close_price'
        ]
        
        X = df[feature_columns].fillna(0)
        y = df['next_price_change']
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        # Train XGBoost regressor
        xgb_model = xgb.XGBRegressor(n_estimators=100, random_state=42)
        xgb_model.fit(X_train_scaled, y_train)
        
        # Predictions
        y_pred = xgb_model.predict(X_test_scaled)
        
        # Performance metrics
        mse = mean_squared_error(y_test, y_pred)
        rmse = np.sqrt(mse)
        cv_scores = cross_val_score(xgb_model, X_train_scaled, y_train, cv=5, scoring='neg_mean_squared_error')
        
        # Feature importance
        feature_importance = pd.DataFrame({
            'feature': X.columns,
            'importance': xgb_model.feature_importances_
        }).sort_values('importance', ascending=False)
        
        results = {
            'model': xgb_model,
            'mse': mse,
            'rmse': rmse,
            'cv_mean': -cv_scores.mean(),
            'cv_std': cv_scores.std(),
            'feature_importance': feature_importance
        }
        
        print(f"Price Predictor Performance:")
        print(f"RMSE: {rmse:.5f}")
        print(f"CV MSE: {-cv_scores.mean():.5f} (+/- {cv_scores.std() * 2:.5f})")
        print("\nTop 10 Most Important Features:")
        print(feature_importance.head(10))
        
        return results
    
    def analyze_regime_patterns(self) -> dict:
        """
        Analyze market regime patterns and transitions
        
        Returns:
            Dictionary with regime analysis results
        """
        if self.regime_data is None:
            raise ValueError("Regime data not loaded")
        
        df = self.regime_data.copy()
        
        # Regime distribution
        regime_counts = df['regime'].value_counts()
        regime_percentages = df['regime'].value_counts(normalize=True) * 100
        
        # Regime transitions
        df['next_regime'] = df['regime'].shift(-1)
        transitions = df.groupby(['regime', 'next_regime']).size().unstack(fill_value=0)
        
        # Regime duration analysis
        df['regime_change'] = df['regime'] != df['regime'].shift(1)
        df['regime_group'] = df['regime_change'].cumsum()
        regime_durations = df.groupby('regime_group')['regime'].agg(['first', 'count']).reset_index()
        regime_durations.columns = ['group', 'regime', 'duration']
        
        avg_duration = regime_durations.groupby('regime')['duration'].mean()
        
        results = {
            'regime_distribution': regime_counts,
            'regime_percentages': regime_percentages,
            'transition_matrix': transitions,
            'average_duration': avg_duration,
            'regime_durations': regime_durations
        }
        
        print("Market Regime Analysis:")
        print("\nRegime Distribution:")
        for regime, count in regime_counts.items():
            print(f"  {regime}: {count} ({regime_percentages[regime]:.1f}%)")
        
        print("\nAverage Regime Duration:")
        for regime, duration in avg_duration.items():
            print(f"  {regime}: {duration:.1f} periods")
        
        return results
    
    def analyze_performance_by_regime(self) -> dict:
        """
        Analyze trading performance by market regime
        
        Returns:
            Dictionary with performance analysis results
        """
        if self.performance_data is None:
            raise ValueError("Performance data not loaded")
        
        df = self.performance_data.copy()
        
        # Performance by regime
        regime_performance = df.groupby('regime_at_entry').agg({
            'pnl': ['count', 'mean', 'std', 'sum'],
            'duration_minutes': 'mean',
            'outcome': lambda x: (x == 'PROFIT').sum() / len(x) * 100  # Win rate
        }).round(2)
        
        # Performance by signal type
        signal_performance = df.groupby('signal_type').agg({
            'pnl': ['count', 'mean', 'std', 'sum'],
            'duration_minutes': 'mean',
            'outcome': lambda x: (x == 'PROFIT').sum() / len(x) * 100
        }).round(2)
        
        # Risk-adjusted returns
        df['risk_adjusted_return'] = df['pnl'] / df['risk_percent']
        risk_adjusted_by_regime = df.groupby('regime_at_entry')['risk_adjusted_return'].agg(['mean', 'std']).round(3)
        
        results = {
            'regime_performance': regime_performance,
            'signal_performance': signal_performance,
            'risk_adjusted_returns': risk_adjusted_by_regime
        }
        
        print("Performance Analysis by Regime:")
        print(regime_performance)
        
        print("\nPerformance Analysis by Signal Type:")
        print(signal_performance)
        
        return results
    
    def optimize_parameters(self) -> dict:
        """
        Optimize trading parameters using grid search
        
        Returns:
            Dictionary with optimization results
        """
        X, y = self.prepare_training_features()
        
        # Parameter grid for Random Forest
        param_grid = {
            'n_estimators': [50, 100, 200],
            'max_depth': [5, 10, 15, None],
            'min_samples_split': [2, 5, 10],
            'min_samples_leaf': [1, 2, 4]
        }
        
        # Grid search
        rf = RandomForestClassifier(random_state=42)
        grid_search = GridSearchCV(rf, param_grid, cv=3, scoring='accuracy', n_jobs=-1)
        grid_search.fit(X, y)
        
        results = {
            'best_params': grid_search.best_params_,
            'best_score': grid_search.best_score_,
            'best_model': grid_search.best_estimator_
        }
        
        print("Parameter Optimization Results:")
        print(f"Best Score: {grid_search.best_score_:.3f}")
        print("Best Parameters:")
        for param, value in grid_search.best_params_.items():
            print(f"  {param}: {value}")
        
        return results
    
    def create_visualizations(self, output_dir: str = "ai_analysis_plots"):
        """
        Create visualization plots for analysis
        
        Args:
            output_dir: Directory to save plots
        """
        import os
        os.makedirs(output_dir, exist_ok=True)
        
        plt.style.use('seaborn-v0_8')
        
        # 1. Feature importance plot
        if self.training_data is not None:
            X, y = self.prepare_training_features()
            rf_model = RandomForestClassifier(n_estimators=100, random_state=42)
            rf_model.fit(X, y)
            
            feature_importance = pd.DataFrame({
                'feature': X.columns,
                'importance': rf_model.feature_importances_
            }).sort_values('importance', ascending=True)
            
            plt.figure(figsize=(10, 8))
            plt.barh(feature_importance['feature'], feature_importance['importance'])
            plt.title('Feature Importance for Trade Success Prediction')
            plt.xlabel('Importance')
            plt.tight_layout()
            plt.savefig(os.path.join(output_dir, 'feature_importance.png'), dpi=300, bbox_inches='tight')
            plt.close()
        
        # 2. Regime distribution pie chart
        if self.regime_data is not None:
            plt.figure(figsize=(8, 8))
            regime_counts = self.regime_data['regime'].value_counts()
            plt.pie(regime_counts.values, labels=regime_counts.index, autopct='%1.1f%%')
            plt.title('Market Regime Distribution')
            plt.savefig(os.path.join(output_dir, 'regime_distribution.png'), dpi=300, bbox_inches='tight')
            plt.close()
        
        # 3. Performance by regime
        if self.performance_data is not None:
            plt.figure(figsize=(12, 6))
            regime_pnl = self.performance_data.groupby('regime_at_entry')['pnl'].mean()
            regime_pnl.plot(kind='bar')
            plt.title('Average P&L by Market Regime')
            plt.ylabel('Average P&L')
            plt.xticks(rotation=45)
            plt.tight_layout()
            plt.savefig(os.path.join(output_dir, 'performance_by_regime.png'), dpi=300, bbox_inches='tight')
            plt.close()
        
        print(f"Visualizations saved to {output_dir}")

def main():
    """Main function for command-line usage"""
    import argparse
    
    parser = argparse.ArgumentParser(description='AI Analysis Tools for Grande Trading System')
    parser.add_argument('--data-dir', default='ai_data_export', help='Directory containing CSV files')
    parser.add_argument('--symbol', default='EURUSD', help='Trading symbol to analyze')
    parser.add_argument('--analysis', choices=[
        'classifier', 'predictor', 'regime', 'performance', 'optimize', 'all'
    ], default='all', help='Type of analysis to perform')
    parser.add_argument('--output-dir', default='ai_analysis_results', help='Output directory for results')
    
    args = parser.parse_args()
    
    # Initialize analyzer
    analyzer = GrandeAIAnalyzer(args.data_dir)
    
    try:
        # Load data
        analyzer.load_data(args.symbol)
        
        # Perform analysis
        if args.analysis in ['classifier', 'all']:
            print("\n" + "="*50)
            print("TRAINING SIGNAL CLASSIFIER")
            print("="*50)
            classifier_results = analyzer.train_signal_classifier()
        
        if args.analysis in ['predictor', 'all']:
            print("\n" + "="*50)
            print("TRAINING PRICE PREDICTOR")
            print("="*50)
            predictor_results = analyzer.train_price_predictor()
        
        if args.analysis in ['regime', 'all']:
            print("\n" + "="*50)
            print("ANALYZING REGIME PATTERNS")
            print("="*50)
            regime_results = analyzer.analyze_regime_patterns()
        
        if args.analysis in ['performance', 'all']:
            print("\n" + "="*50)
            print("ANALYZING PERFORMANCE BY REGIME")
            print("="*50)
            performance_results = analyzer.analyze_performance_by_regime()
        
        if args.analysis in ['optimize', 'all']:
            print("\n" + "="*50)
            print("OPTIMIZING PARAMETERS")
            print("="*50)
            optimization_results = analyzer.optimize_parameters()
        
        # Create visualizations
        print("\n" + "="*50)
        print("CREATING VISUALIZATIONS")
        print("="*50)
        analyzer.create_visualizations(args.output_dir)
        
        print(f"\nAnalysis complete! Results saved to {args.output_dir}")
    
    except Exception as e:
        print(f"Error during analysis: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
