"""
高度なテスト - エッジケースと統合テスト

天気予報・掲示板ツールの詳細な機能テストを実施する。
"""

import unittest
import os
import json
from datetime import datetime
from io import StringIO
import sys

from weather import Weather
from bulletin import Bulletin


class TestWeatherEdgeCases(unittest.TestCase):
    """Weather クラスのエッジケーステスト"""

    def setUp(self):
        self.weather = Weather()

    def test_empty_city_name(self):
        """空の都市名でも forecast() が動作するか"""
        result = self.weather.forecast("")
        self.assertEqual(result["city"], "")
        self.assertIn(result["weather"], self.weather.WEATHER_PATTERNS)

    def test_long_city_name(self):
        """長い都市名でも forecast() が動作するか"""
        long_city = "テスト" * 50
        result = self.weather.forecast(long_city)
        self.assertEqual(result["city"], long_city)

    def test_special_characters_in_city(self):
        """特殊文字を含む都市名でも動作するか"""
        cities = ["東京都", "San Francisco", "北京", "モスクワ", "ニューヨーク"]
        for city in cities:
            result = self.weather.forecast(city)
            self.assertEqual(result["city"], city)

    def test_temperature_boundary_min(self):
        """気温が最小値を返すことはあるか"""
        temps = [self.weather.get_random_temperature() for _ in range(100)]
        self.assertIn(self.weather.MIN_TEMPERATURE, temps)

    def test_temperature_boundary_max(self):
        """気温が最大値を返すことはあるか"""
        temps = [self.weather.get_random_temperature() for _ in range(500)]
        self.assertIn(self.weather.MAX_TEMPERATURE, temps)

    def test_all_weather_patterns_generated(self):
        """すべての天気パターンが生成されるか"""
        weathers = [self.weather.get_random_weather() for _ in range(100)]
        for pattern in self.weather.WEATHER_PATTERNS:
            self.assertIn(pattern, weathers)

    def test_forecast_consistency(self):
        """同じ都市でも毎回異なる予報が生成されるか"""
        city = "テスト市"
        results = [self.weather.forecast(city) for _ in range(10)]

        # すべて都市名は同じ
        for result in results:
            self.assertEqual(result["city"], city)

        # 天気または気温に変動がある
        weathers = [r["weather"] for r in results]
        temps = [r["temperature"] for r in results]
        has_variety = len(set(weathers)) > 1 or len(set(temps)) > 1
        self.assertTrue(has_variety)


class TestBulletinEdgeCases(unittest.TestCase):
    """Bulletin クラスのエッジケーステスト"""

    def setUp(self):
        self.bulletin = Bulletin()
        self.test_message_file = "data/test_advanced_messages.json"
        self.original_message_file = self.bulletin.MESSAGE_FILE
        self.bulletin.MESSAGE_FILE = self.test_message_file

        if os.path.exists(self.test_message_file):
            os.remove(self.test_message_file)

    def tearDown(self):
        if os.path.exists(self.test_message_file):
            os.remove(self.test_message_file)
        self.bulletin.MESSAGE_FILE = self.original_message_file

    def test_empty_author_name(self):
        """空の投稿者名でメッセージが保存されるか"""
        message = "テストメッセージ"
        self.bulletin.post_message("", message)

        messages = self.bulletin.get_messages()
        self.assertEqual(len(messages), 1)
        self.assertEqual(messages[0]["author"], "")

    def test_empty_message_text(self):
        """空のメッセージテキストが保存されるか"""
        author = "テスト太郎"
        self.bulletin.post_message(author, "")

        messages = self.bulletin.get_messages()
        self.assertEqual(len(messages), 1)
        self.assertEqual(messages[0]["message"], "")

    def test_very_long_message(self):
        """非常に長いメッセージが保存されるか"""
        author = "テスト太郎"
        message = "あ" * 10000
        self.bulletin.post_message(author, message)

        messages = self.bulletin.get_messages()
        self.assertEqual(len(messages), 1)
        self.assertEqual(messages[0]["message"], message)

    def test_special_characters_in_message(self):
        """特殊文字（改行、タブ、引用符など）が正しく保存されるか"""
        author = "テスト太郎"
        message = 'これは"テスト"です。\n改行を含みます。\tタブも含みます。'
        self.bulletin.post_message(author, message)

        messages = self.bulletin.get_messages()
        self.assertEqual(messages[0]["message"], message)

    def test_emoji_support(self):
        """絵文字が正しく保存されるか"""
        author = "テスト太郎"
        message = "これはテストです 😀 🎉 ✨"
        self.bulletin.post_message(author, message)

        messages = self.bulletin.get_messages()
        self.assertEqual(messages[0]["message"], message)

    def test_message_order_preserved(self):
        """メッセージの順序が投稿順に保持されるか"""
        authors = [f"ユーザー{i}" for i in range(5)]
        messages = [f"メッセージ{i}" for i in range(5)]

        for author, message in zip(authors, messages):
            self.bulletin.post_message(author, message)

        retrieved = self.bulletin.get_messages()
        for i, (author, message) in enumerate(zip(authors, messages)):
            self.assertEqual(retrieved[i]["author"], author)
            self.assertEqual(retrieved[i]["message"], message)

    def test_timestamp_ordering(self):
        """タイムスタンプが時系列順になっているか"""
        for i in range(3):
            self.bulletin.post_message(f"ユーザー{i}", f"メッセージ{i}")

        messages = self.bulletin.get_messages()
        for i in range(len(messages) - 1):
            ts1 = datetime.fromisoformat(messages[i]["timestamp"])
            ts2 = datetime.fromisoformat(messages[i + 1]["timestamp"])
            self.assertLessEqual(ts1, ts2)

    def test_json_pretty_print(self):
        """JSON ファイルがインデント形式で保存されるか"""
        author = "テスト太郎"
        message = "テストメッセージ"
        self.bulletin.post_message(author, message)

        with open(self.test_message_file, "r", encoding="utf-8") as f:
            content = f.read()

        # インデント形式の確認（改行と空白が含まれる）
        self.assertIn("\n", content)

    def test_multiple_file_access(self):
        """ファイルを複数回アクセスしても正しく動作するか"""
        for i in range(5):
            self.bulletin.post_message(f"ユーザー{i}", f"メッセージ{i}")

        # 読み込みテスト
        for _ in range(3):
            messages = self.bulletin.get_messages()
            self.assertEqual(len(messages), 5)

        # 追加テスト
        self.bulletin.post_message("ユーザー5", "メッセージ5")
        messages = self.bulletin.get_messages()
        self.assertEqual(len(messages), 6)

    def test_unicode_normalization(self):
        """異なる Unicode 形式の文字が正しく保存されるか"""
        author = "テスト太郎"
        # 日本語、中国語、韓国語、ロシア語などの混合
        message = "こんにちは你好안녕하세요Привет"
        self.bulletin.post_message(author, message)

        messages = self.bulletin.get_messages()
        self.assertEqual(messages[0]["message"], message)

    def test_load_messages_preserves_data(self):
        """load_messages() でデータが破損していないか確認"""
        messages_to_save = [
            {"timestamp": "2026-01-28T10:00:00", "author": "ユーザー1", "message": "メッセージ1"},
            {"timestamp": "2026-01-28T10:01:00", "author": "ユーザー2", "message": "メッセージ2"},
        ]

        self.bulletin.save_messages(messages_to_save)
        loaded_messages = self.bulletin.load_messages()

        self.assertEqual(loaded_messages, messages_to_save)


class TestIntegration(unittest.TestCase):
    """統合テスト"""

    def setUp(self):
        self.weather = Weather()
        self.bulletin = Bulletin()
        self.test_message_file = "data/test_integration_messages.json"
        self.original_message_file = self.bulletin.MESSAGE_FILE
        self.bulletin.MESSAGE_FILE = self.test_message_file

        if os.path.exists(self.test_message_file):
            os.remove(self.test_message_file)

    def tearDown(self):
        if os.path.exists(self.test_message_file):
            os.remove(self.test_message_file)
        self.bulletin.MESSAGE_FILE = self.original_message_file

    def test_weather_and_bulletin_independent(self):
        """Weather と Bulletin が独立して動作するか"""
        # Weather テスト
        forecast = self.weather.forecast("東京")
        self.assertIn("city", forecast)

        # Bulletin テスト
        self.bulletin.post_message("ユーザー1", "メッセージ1")
        messages = self.bulletin.get_messages()
        self.assertEqual(len(messages), 1)

        # Weather が Bulletin に影響しないか確認
        forecast2 = self.weather.forecast("大阪")
        messages2 = self.bulletin.get_messages()
        self.assertEqual(len(messages2), 1)

    def test_scenario_village_tool_usage(self):
        """実際の使用シナリオをシミュレート"""
        # ユーザー1が天気を確認
        forecast1 = self.weather.forecast("福岡")
        self.assertIsNotNone(forecast1)

        # ユーザー1がメッセージを投稿
        self.bulletin.post_message("田中太郎", "今日も晴れるといいですね。")

        # ユーザー2が天気を確認
        forecast2 = self.weather.forecast("東京")
        self.assertIsNotNone(forecast2)

        # ユーザー2がメッセージを投稿
        self.bulletin.post_message("佐藤花子", "天気予報をありがとうございます。")

        # すべてのメッセージを確認
        all_messages = self.bulletin.get_messages()
        self.assertEqual(len(all_messages), 2)
        self.assertEqual(all_messages[0]["author"], "田中太郎")
        self.assertEqual(all_messages[1]["author"], "佐藤花子")


class TestDisplayFunctions(unittest.TestCase):
    """表示機能のテスト"""

    def setUp(self):
        self.weather = Weather()
        self.bulletin = Bulletin()

    def test_display_forecast_output(self):
        """display_forecast() が出力を生成するか"""
        forecast_data = {
            "city": "テスト市",
            "weather": "晴れ",
            "temperature": 25
        }

        # 出力をキャプチャ
        captured_output = StringIO()
        sys.stdout = captured_output
        self.weather.display_forecast(forecast_data)
        sys.stdout = sys.__stdout__

        output = captured_output.getvalue()
        self.assertIn("テスト市", output)
        self.assertIn("晴れ", output)
        self.assertIn("25", output)

    def test_display_messages_empty(self):
        """display_messages() が空時に正しく表示するか"""
        # テスト用に一時的に MESSAGE_FILE を変更
        original = self.bulletin.MESSAGE_FILE
        self.bulletin.MESSAGE_FILE = "data/test_display_empty.json"

        if os.path.exists(self.bulletin.MESSAGE_FILE):
            os.remove(self.bulletin.MESSAGE_FILE)

        captured_output = StringIO()
        sys.stdout = captured_output
        self.bulletin.display_messages()
        sys.stdout = sys.__stdout__

        output = captured_output.getvalue()
        self.assertIn("メッセージはありません", output)

        # 復元
        if os.path.exists(self.bulletin.MESSAGE_FILE):
            os.remove(self.bulletin.MESSAGE_FILE)
        self.bulletin.MESSAGE_FILE = original


def run_advanced_tests():
    """高度なテストスイートの実行"""
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    suite.addTests(loader.loadTestsFromTestCase(TestWeatherEdgeCases))
    suite.addTests(loader.loadTestsFromTestCase(TestBulletinEdgeCases))
    suite.addTests(loader.loadTestsFromTestCase(TestIntegration))
    suite.addTests(loader.loadTestsFromTestCase(TestDisplayFunctions))

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    return result


if __name__ == "__main__":
    result = run_advanced_tests()
    sys.exit(0 if result.wasSuccessful() else 1)
