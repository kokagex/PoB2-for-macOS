"""
Comprehensive Test Suite for Parts Extractor Application

Tests all components: API, data analysis, UI initialization, and export functionality.
"""

import unittest
import pandas as pd
import os
import sys
from io import StringIO

# Import modules to test
import mock_data
import data_analyzer
import sheets_api
import data_storage


class TestMockData(unittest.TestCase):
    """Test mock data generation and validation."""

    def test_get_mock_data_returns_dataframe(self):
        """Test that mock data function returns a DataFrame."""
        df = mock_data.get_mock_data()
        self.assertIsInstance(df, pd.DataFrame)

    def test_mock_data_has_required_columns(self):
        """Test that mock data has all required columns."""
        df = mock_data.get_mock_data()
        required_columns = ["part_id", "part_name", "process_count", "amount", "manufacturer", "notes"]
        for col in required_columns:
            self.assertIn(col, df.columns, f"Column '{col}' missing from mock data")

    def test_mock_data_is_not_empty(self):
        """Test that mock data is not empty."""
        df = mock_data.get_mock_data()
        self.assertGreater(len(df), 0, "Mock data should not be empty")

    def test_mock_data_types(self):
        """Test that mock data has correct types."""
        df = mock_data.get_mock_data()
        self.assertTrue(pd.api.types.is_integer_dtype(df["process_count"]), "process_count should be integer")
        self.assertTrue(pd.api.types.is_numeric_dtype(df["amount"]), "amount should be numeric")

    def test_create_empty_dataframe(self):
        """Test creating an empty DataFrame with correct schema."""
        df = mock_data.create_empty_dataframe()
        required_columns = ["part_id", "part_name", "process_count", "amount", "manufacturer", "notes"]
        self.assertEqual(list(df.columns), required_columns)
        self.assertEqual(len(df), 0)

    def test_validate_mock_data_valid(self):
        """Test validation of valid mock data."""
        df = mock_data.get_mock_data()
        is_valid, msg = mock_data.validate_mock_data(df)
        self.assertTrue(is_valid, f"Valid mock data should pass validation: {msg}")

    def test_validate_mock_data_empty(self):
        """Test validation of empty DataFrame."""
        df = mock_data.create_empty_dataframe()
        is_valid, msg = mock_data.validate_mock_data(df)
        self.assertFalse(is_valid, "Empty DataFrame should fail validation")


class TestDataAnalyzer(unittest.TestCase):
    """Test data analysis and filtering functionality."""

    def setUp(self):
        """Set up test fixtures."""
        self.mock_df = mock_data.get_mock_data()
        self.analyzer = data_analyzer.DataAnalyzer(self.mock_df)

    def test_analyzer_initialization(self):
        """Test DataAnalyzer initialization."""
        self.assertIsNotNone(self.analyzer.data)
        self.assertEqual(len(self.analyzer.data), len(self.mock_df))

    def test_validate_data_valid(self):
        """Test data validation with valid data."""
        is_valid, msg = self.analyzer.validate_data()
        self.assertTrue(is_valid, f"Mock data should be valid: {msg}")

    def test_validate_data_empty(self):
        """Test data validation with empty DataFrame."""
        empty_analyzer = data_analyzer.DataAnalyzer(pd.DataFrame())
        is_valid, msg = empty_analyzer.validate_data()
        self.assertFalse(is_valid, "Empty DataFrame should fail validation")

    def test_filter_by_thresholds_valid(self):
        """Test filtering by valid thresholds."""
        filtered = self.analyzer.filter_by_thresholds(max_process_count=3, min_amount=100000)
        self.assertIsInstance(filtered, pd.DataFrame)
        # Check that all results meet criteria
        if len(filtered) > 0:
            self.assertTrue((filtered['process_count'] <= 3).all(), "All should have process_count <= 3")
            self.assertTrue((filtered['amount'] >= 100000).all(), "All should have amount >= 100000")

    def test_filter_by_thresholds_returns_results(self):
        """Test that filtering returns expected results."""
        filtered = self.analyzer.filter_by_thresholds(max_process_count=5, min_amount=50000)
        self.assertGreater(len(filtered), 0, "Should return some results with these thresholds")

    def test_filter_by_thresholds_sorted(self):
        """Test that results are sorted by amount descending."""
        filtered = self.analyzer.filter_by_thresholds(max_process_count=5, min_amount=0)
        if len(filtered) > 1:
            amounts = filtered['amount'].tolist()
            self.assertEqual(amounts, sorted(amounts, reverse=True), "Results should be sorted by amount descending")

    def test_get_filtered_data(self):
        """Test retrieving filtered data."""
        self.analyzer.filter_by_thresholds(max_process_count=3, min_amount=100000)
        filtered = self.analyzer.get_filtered_data()
        self.assertIsInstance(filtered, pd.DataFrame)

    def test_get_filter_summary(self):
        """Test filter summary generation."""
        self.analyzer.filter_by_thresholds(max_process_count=3, min_amount=100000)
        summary = self.analyzer.get_filter_summary()
        self.assertIn('total_rows', summary)
        self.assertIn('total_value', summary)
        self.assertIn('avg_value', summary)
        self.assertGreater(summary['total_rows'], 0)

    def test_export_to_csv(self):
        """Test CSV export functionality."""
        self.analyzer.filter_by_thresholds(max_process_count=3, min_amount=100000)
        success, filepath = self.analyzer.export_to_csv()
        self.assertTrue(success, f"Export should succeed: {filepath}")
        self.assertTrue(os.path.exists(filepath), f"Exported file should exist: {filepath}")
        # Clean up
        if os.path.exists(filepath):
            os.remove(filepath)

    def test_export_to_csv_no_data(self):
        """Test CSV export with no filtered data."""
        analyzer = data_analyzer.DataAnalyzer(self.mock_df)
        success, msg = analyzer.export_to_csv()
        self.assertFalse(success, "Export should fail when no data is filtered")

    def test_reset_filters(self):
        """Test filter reset functionality."""
        self.analyzer.filter_by_thresholds(max_process_count=3, min_amount=100000)
        self.analyzer.reset_filters()
        self.assertIsNone(self.analyzer.filtered_data)
        self.assertEqual(len(self.analyzer.data), len(self.mock_df))

    def test_get_statistics(self):
        """Test statistics generation."""
        stats = self.analyzer.get_statistics()
        self.assertIn('total_parts', stats)
        self.assertIn('columns', stats)
        self.assertEqual(stats['total_parts'], len(self.mock_df))


class TestGoogleSheetsAPI(unittest.TestCase):
    """Test Google Sheets API integration."""

    def test_api_initialization(self):
        """Test API initialization."""
        api = sheets_api.GoogleSheetsAPI()
        # API should initialize even without credentials
        self.assertIsNotNone(api)

    def test_api_uses_mock_data_fallback(self):
        """Test that API falls back to mock data when needed."""
        api = sheets_api.GoogleSheetsAPI()
        # Since credentials.json likely doesn't exist, should use mock
        self.assertTrue(api.is_using_mock_data(), "API should use mock data when credentials unavailable")

    def test_get_sheet_data_returns_dataframe(self):
        """Test that get_sheet_data returns a DataFrame."""
        api = sheets_api.GoogleSheetsAPI()
        df = api.get_sheet_data("dummy_id", "Sheet1")
        self.assertIsInstance(df, pd.DataFrame)

    def test_list_sheets_returns_list(self):
        """Test that list_sheets returns a list."""
        api = sheets_api.GoogleSheetsAPI()
        sheets = api.list_sheets("dummy_id")
        self.assertIsInstance(sheets, list)

    def test_verification_status(self):
        """Test getting verification status."""
        api = sheets_api.GoogleSheetsAPI()
        status = api.get_verification_status()
        self.assertIn('api_available', status)
        self.assertIn('using_mock_data', status)
        self.assertIn('time_elapsed', status)


class TestDataStorage(unittest.TestCase):
    """Test data storage functionality."""

    def setUp(self):
        """Set up test fixtures."""
        self.storage_manager = data_storage.DataStorageManager(data_folder="test_data")
        self.test_df = mock_data.get_mock_data()

    def tearDown(self):
        """Clean up test files."""
        import shutil
        if os.path.exists("test_data"):
            shutil.rmtree("test_data")

    def test_storage_manager_initialization(self):
        """Test DataStorageManager initialization."""
        self.assertIsNotNone(self.storage_manager)
        self.assertTrue(os.path.exists("test_data"))

    def test_save_to_json_success(self):
        """Test saving DataFrame to JSON."""
        success, filepath = self.storage_manager.save_to_json(
            df=self.test_df,
            spreadsheet_id="test_sheet_123",
            sheet_name="TestSheet"
        )
        self.assertTrue(success)
        self.assertTrue(os.path.exists(filepath))

    def test_save_to_json_with_custom_filename(self):
        """Test saving to JSON with custom filename."""
        success, filepath = self.storage_manager.save_to_json(
            df=self.test_df,
            spreadsheet_id="test_sheet_123",
            sheet_name="TestSheet",
            filename="custom_data.json"
        )
        self.assertTrue(success)
        self.assertIn("custom_data.json", filepath)

    def test_load_from_json(self):
        """Test loading data from JSON."""
        # First save data
        self.storage_manager.save_to_json(
            df=self.test_df,
            spreadsheet_id="test_sheet_123",
            sheet_name="TestSheet"
        )
        # Then load it
        loaded_df, metadata = self.storage_manager.load_from_json()
        self.assertIsNotNone(loaded_df)
        self.assertEqual(len(loaded_df), len(self.test_df))
        self.assertIn('spreadsheet_id', metadata)

    def test_json_metadata_structure(self):
        """Test that saved JSON has correct metadata."""
        self.storage_manager.save_to_json(
            df=self.test_df,
            spreadsheet_id="test_sheet_123",
            sheet_name="TestSheet"
        )
        loaded_df, metadata = self.storage_manager.load_from_json()
        self.assertEqual(metadata['spreadsheet_id'], "test_sheet_123")
        self.assertEqual(metadata['sheet_name'], "TestSheet")
        self.assertEqual(metadata['row_count'], len(self.test_df))
        self.assertIn('fetched_at', metadata)

    def test_save_empty_dataframe(self):
        """Test saving empty DataFrame."""
        empty_df = pd.DataFrame()
        success, filepath = self.storage_manager.save_to_json(
            df=empty_df,
            spreadsheet_id="test_123",
            sheet_name="Empty"
        )
        self.assertFalse(success)

    def test_file_exists_check(self):
        """Test checking if file exists."""
        self.assertFalse(self.storage_manager.file_exists())
        self.storage_manager.save_to_json(
            df=self.test_df,
            spreadsheet_id="test_123",
            sheet_name="Test"
        )
        self.assertTrue(self.storage_manager.file_exists())

    def test_get_file_info(self):
        """Test retrieving file information."""
        self.storage_manager.save_to_json(
            df=self.test_df,
            spreadsheet_id="test_123",
            sheet_name="Test"
        )
        info = self.storage_manager.get_file_info()
        self.assertTrue(info['exists'])
        self.assertIn('size_bytes', info)
        self.assertIn('last_modified', info)


class TestIntegration(unittest.TestCase):
    """Integration tests for complete workflow."""

    def test_complete_workflow(self):
        """Test complete workflow: get data -> filter -> export."""
        # Initialize API
        api = sheets_api.GoogleSheetsAPI()

        # Get data
        df = api.get_sheet_data("dummy_id", "Sheet1")
        self.assertGreater(len(df), 0)

        # Create analyzer
        analyzer = data_analyzer.DataAnalyzer(df)

        # Validate
        is_valid, msg = analyzer.validate_data()
        self.assertTrue(is_valid)

        # Filter
        filtered = analyzer.filter_by_thresholds(max_process_count=3, min_amount=100000)
        self.assertGreater(len(filtered), 0)

        # Export
        success, filepath = analyzer.export_to_csv()
        self.assertTrue(success)

        # Clean up
        if os.path.exists(filepath):
            os.remove(filepath)

    def test_error_handling_invalid_threshold(self):
        """Test error handling with invalid thresholds."""
        analyzer = data_analyzer.DataAnalyzer(mock_data.get_mock_data())
        # Test with negative threshold
        filtered = analyzer.filter_by_thresholds(max_process_count=-1, min_amount=100000)
        # Should return empty DataFrame on error
        self.assertIsInstance(filtered, pd.DataFrame)


class TestDataIntegrity(unittest.TestCase):
    """Test data integrity and edge cases."""

    def test_large_dataset_filtering(self):
        """Test filtering with larger dataset."""
        df = mock_data.get_mock_data()
        # Create a larger dataset by concatenating
        large_df = pd.concat([df] * 10, ignore_index=True)
        analyzer = data_analyzer.DataAnalyzer(large_df)
        filtered = analyzer.filter_by_thresholds(max_process_count=3, min_amount=100000)
        self.assertGreater(len(filtered), 0)

    def test_edge_case_zero_threshold(self):
        """Test filtering with zero as threshold."""
        analyzer = data_analyzer.DataAnalyzer(mock_data.get_mock_data())
        filtered = analyzer.filter_by_thresholds(max_process_count=0, min_amount=0)
        self.assertIsInstance(filtered, pd.DataFrame)

    def test_edge_case_all_filtered_out(self):
        """Test filtering that results in no matches."""
        analyzer = data_analyzer.DataAnalyzer(mock_data.get_mock_data())
        # Very high threshold that no parts will match
        filtered = analyzer.filter_by_thresholds(max_process_count=0, min_amount=1000000000)
        self.assertEqual(len(filtered), 0, "Should have no results with impossible threshold")


def run_tests():
    """Run all tests and print report."""
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add test classes
    suite.addTests(loader.loadTestsFromTestCase(TestMockData))
    suite.addTests(loader.loadTestsFromTestCase(TestDataAnalyzer))
    suite.addTests(loader.loadTestsFromTestCase(TestGoogleSheetsAPI))
    suite.addTests(loader.loadTestsFromTestCase(TestDataStorage))
    suite.addTests(loader.loadTestsFromTestCase(TestIntegration))
    suite.addTests(loader.loadTestsFromTestCase(TestDataIntegrity))

    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Print summary
    print("\n" + "="*70)
    print("TEST SUMMARY")
    print("="*70)
    print(f"Tests run: {result.testsRun}")
    print(f"Successes: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print("="*70)

    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
