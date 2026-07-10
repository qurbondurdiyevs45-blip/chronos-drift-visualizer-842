import sqlite3
import numpy as np
from datetime import datetime, timedelta
import sys
import os

class ChronosDriftAnalyzer:
    def __init__(self, db_path="data/chronos_drift.db"):
        if not os.path.exists(os.path.dirname(db_path)):
            os.makedirs(os.path.dirname(db_path), exist_ok=True)
        self.db_path = db_path
        self._initialize_db()

    def _initialize_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS drift_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    drift_microseconds INTEGER NOT NULL,
                    source_str TEXT NOT NULL
                )
            """)

    def fetch_recent_data(self, limit=1000):
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT strftime('%s', timestamp), drift_microseconds 
                FROM drift_logs 
                ORDER BY timestamp DESC 
                LIMIT ?
            """, (limit,))
            data = cursor.fetchall()
        
        if not data:
            return None, None
            
        data = np.array(data, dtype=np.float64)
        # Flip to chronological order
        data = data[::-1]
        
        # Normalize timestamps relative to the first entry
        timestamps = data[:, 0] - data[0, 0]
        drift_values = data[:, 1]
        return timestamps, drift_values

    def calculate_drift_velocity(self, timestamps, drift_values):
        """
        Performs linear regression to find the rate of drift over time.
        Returns (slope, intercept, r_squared)
        Slope is in microseconds per second.
        """
        if len(timestamps) < 2:
            return 0.0, 0.0, 0.0

        A = np.vstack([timestamps, np.ones(len(timestamps))]).T
        m, c = np.linalg.lstsq(A, drift_values, rcond=None)[0]
        
        # Calculate R-squared
        residuals = drift_values - (m * timestamps + c)
        ss_res = np.sum(residuals**2)
        ss_tot = np.sum((drift_values - np.mean(drift_values))**2)
        r_squared = 1 - (ss_res / ss_tot) if ss_tot != 0 else 0
        
        return m, c, r_squared

    def generate_report(self):
        t, d = self.fetch_recent_data()
        
        if t is None or len(t) < 5:
            print("Error: Insufficient data points for statistical analysis.")
            return

        slope, intercept, r2 = self.calculate_drift_velocity(t, d)
        
        mean_drift = np.mean(d)
        std_dev = np.std(d)
        max_drift = np.max(np.abs(d))
        
        # Predicted drift over 24 hours (86400 seconds)
        prediction_24h = slope * 86400

        print("--- Chronos Drift Statistical Analysis ---")
        print(f"Data points analyzed: {len(t)}")
        print(f"Mean Drift:           {mean_drift:.4f} μs")
        print(f"Standard Deviation:   {std_dev:.4f} μs")
        print(f"Maximum Deviation:    {max_drift:.4f} μs")
        print("-" * 42)
        print(f"Drift Velocity:       {slope:.6f} μs/sec")
        print(f"R-Squared Confidence: {r2:.6f}")
        print(f"Predicted Daily Skew: {prediction_24h / 1000:.4f} ms/day")
        print("-" * 42)

        if r2 > 0.8:
            print("Assessment: High clock stability, linear drift detected.")
        elif r2 > 0.4:
            print("Assessment: Moderate jitter detected. Hardware clock inconsistent.")
        else:
            print("Assessment: High noise/jitter. Network latency likely impacting accuracy.")

if __name__ == "__main__":
    db_file = os.getenv("CHRONOS_DB_PATH", "data/chronos_drift.db")
    analyzer = ChronosDriftAnalyzer(db_file)
    
    try:
        analyzer.generate_report()
    except Exception as e:
        print(f"Analysis Failed: {str(e)}")
        sys.exit(1)