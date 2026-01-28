"""
Data Storage Module

Handles saving and loading data from JSON files.
Manages data persistence with metadata and timestamps.
"""

import os
import json
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import pandas as pd


class DataStorageManager:
    """
    Manages data storage to JSON files.

    Features:
    - Save DataFrame to JSON with metadata
    - Automatic data folder creation
    - Timestamp recording
    - UTF-8 encoding with proper formatting
    - Error handling and logging
    """

    # Default data folder
    DATA_FOLDER = "data"
    DEFAULT_FILENAME = "parts_list.json"

    def __init__(self, data_folder: str = None):
        """
        Initialize data storage manager.

        Args:
            data_folder: Path to data folder (default: "data")
        """
        self.data_folder = data_folder or self.DATA_FOLDER
        self._ensure_data_folder()

    def _ensure_data_folder(self) -> None:
        """Ensure data folder exists, create if necessary."""
        try:
            os.makedirs(self.data_folder, exist_ok=True)
        except Exception as e:
            print(f"Error creating data folder: {e}")
            raise

    def save_to_json(
        self,
        df: pd.DataFrame,
        spreadsheet_id: str,
        sheet_name: str,
        filename: str = None
    ) -> Tuple[bool, str]:
        """
        Save DataFrame to JSON file with metadata.

        Args:
            df: DataFrame to save
            spreadsheet_id: Google Sheets spreadsheet ID
            sheet_name: Name of the sheet
            filename: Output filename (default: parts_list.json)

        Returns:
            Tuple of (success: bool, message: str)
        """
        try:
            if filename is None:
                filename = self.DEFAULT_FILENAME

            # Validate input
            if df is None or len(df) == 0:
                return False, "DataFrame is empty or None"

            # Build file path
            filepath = os.path.join(self.data_folder, filename)

            # Create metadata
            metadata = self._create_metadata(
                spreadsheet_id=spreadsheet_id,
                sheet_name=sheet_name,
                row_count=len(df)
            )

            # Prepare data structure
            data_dict = {
                "metadata": metadata,
                "columns": list(df.columns),
                "data": df.to_dict(orient='records')
            }

            # Write to JSON file
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(data_dict, f, ensure_ascii=False, indent=2)

            return True, filepath

        except Exception as e:
            error_msg = f"Failed to save JSON: {str(e)}"
            print(error_msg)
            return False, error_msg

    def load_from_json(self, filename: str = None) -> Tuple[Optional[pd.DataFrame], Dict]:
        """
        Load data from JSON file.

        Args:
            filename: JSON filename to load (default: parts_list.json)

        Returns:
            Tuple of (DataFrame or None, metadata dict)
        """
        try:
            if filename is None:
                filename = self.DEFAULT_FILENAME

            filepath = os.path.join(self.data_folder, filename)

            if not os.path.exists(filepath):
                return None, {}

            with open(filepath, 'r', encoding='utf-8') as f:
                data_dict = json.load(f)

            # Extract metadata and data
            metadata = data_dict.get('metadata', {})
            columns = data_dict.get('columns', [])
            data = data_dict.get('data', [])

            # Reconstruct DataFrame
            if data:
                df = pd.DataFrame(data, columns=columns)
                return df, metadata
            else:
                return pd.DataFrame(), metadata

        except Exception as e:
            print(f"Error loading JSON: {e}")
            return None, {}

    def _create_metadata(
        self,
        spreadsheet_id: str,
        sheet_name: str,
        row_count: int
    ) -> Dict:
        """
        Create metadata dictionary.

        Args:
            spreadsheet_id: Google Sheets spreadsheet ID
            sheet_name: Name of the sheet
            row_count: Number of rows in data

        Returns:
            Metadata dictionary
        """
        return {
            "spreadsheet_id": spreadsheet_id,
            "sheet_name": sheet_name,
            "fetched_at": datetime.now().isoformat(),
            "row_count": row_count
        }

    def get_json_path(self, filename: str = None) -> str:
        """
        Get full path to JSON file.

        Args:
            filename: JSON filename (default: parts_list.json)

        Returns:
            Full file path
        """
        if filename is None:
            filename = self.DEFAULT_FILENAME

        return os.path.join(self.data_folder, filename)

    def file_exists(self, filename: str = None) -> bool:
        """
        Check if JSON file exists.

        Args:
            filename: JSON filename (default: parts_list.json)

        Returns:
            True if file exists, False otherwise
        """
        filepath = self.get_json_path(filename)
        return os.path.exists(filepath)

    def get_file_info(self, filename: str = None) -> Dict:
        """
        Get information about saved JSON file.

        Args:
            filename: JSON filename (default: parts_list.json)

        Returns:
            Dictionary with file information
        """
        filepath = self.get_json_path(filename)

        if not os.path.exists(filepath):
            return {"exists": False}

        try:
            stat_info = os.stat(filepath)
            with open(filepath, 'r', encoding='utf-8') as f:
                data_dict = json.load(f)

            metadata = data_dict.get('metadata', {})

            return {
                "exists": True,
                "filepath": filepath,
                "size_bytes": stat_info.st_size,
                "last_modified": datetime.fromtimestamp(stat_info.st_mtime).isoformat(),
                "metadata": metadata,
                "row_count": metadata.get('row_count', 0)
            }
        except Exception as e:
            return {"exists": True, "error": str(e)}
