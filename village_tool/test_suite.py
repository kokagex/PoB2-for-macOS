"""
テストスイート

天気予報・掲示板ツールの機能テストを実施する。
"""

import unittest
import sys
import os
import json
from datetime import datetime
import shutil

# モジュールインポート
from weather import Weather
from bulletin import Bulletin


class TestWeather(unittest.TestCase):
    """Weather クラスのテスト"""

    def setUp(self):
        """各テスト前の初期化"""
        self.weather = Weather()

    def test_weather_instantiation(self):
        """Weather クラスのインスタンス化テスト"""
        self.assertIsInstance(self.weather, Weather)

    def test_get_random_weather(self):
        """get_random_weather() が定義パターン内の値を返すか"""
        for _ in range(10):
            weather = self.weather.get_random_weather()
            self.assertIn(weather, self.weather.WEATHER_PATTERNS)

    def test_get_random_temperature(self):
        """get_random_temperature() が指定範囲内の値を返すか"""
        for _ in range(10):
            temp = self.weather.get_random_temperature()
            self.assertGreaterEqual(temp, self.weather.MIN_TEMPERATURE)
            self.assertLessEqual(temp, self.weather.MAX_TEMPERATURE)
            self.assertIsInstance(temp, int)

    def test_forecast_returns_dict(self):
        """forecast() が辞書を返すか"""
        city = "東京"
        result = self.weather.forecast(city)
        self.assertIsInstance(result, dict)

    def test_forecast_contains_required_keys(self):
        """forecast() が必須キーをすべて含むか"""
        city = "大阪"
        result = self.weather.forecast(city)
        self.assertIn("city", result)
        self.assertIn("weather", result)
        self.assertIn("temperature", result)

    def test_forecast_city_name_matches(self):
        """forecast() の city が入力値と一致するか"""
        city = "北海道"
        result = self.weather.forecast(city)
        self.assertEqual(result["city"], city)

    def test_forecast_weather_valid(self):
        """forecast() の weather が定義パターン内か"""
        city = "福岡"
        result = self.weather.forecast(city)
        self.assertIn(result["weather"], self.weather.WEATHER_PATTERNS)

    def test_forecast_temperature_valid(self):
        """forecast() の temperature が範囲内か"""
        city = "京都"
        result = self.weather.forecast(city)
        self.assertGreaterEqual(result["temperature"], self.weather.MIN_TEMPERATURE)
        self.assertLessEqual(result["temperature"], self.weather.MAX_TEMPERATURE)
        self.assertIsInstance(result["temperature"], int)

    def test_forecast_multiple_calls_produce_variety(self):
        """複数回の forecast() 呼び出しでバリエーション確認"""
        city = "テスト市"
        results = [self.weather.forecast(city) for _ in range(5)]
        # すべてが同じわけではないことを確認（確率的テスト）
        weathers = [r["weather"] for r in results]
        temps = [r["temperature"] for r in results]
        # 少なくとも天気か気温に変動があることを確認
        self.assertTrue(
            len(set(weathers)) > 1 or len(set(temps)) > 1,
            "複数回の forecast() で変動がない"
        )


class TestBulletin(unittest.TestCase):
    """Bulletin クラスのテスト"""

    def setUp(self):
        """各テスト前の初期化"""
        self.bulletin = Bulletin()
        # テスト用ファイルパスを使用
        self.test_message_file = "data/test_messages.json"
        self.original_message_file = self.bulletin.MESSAGE_FILE
        self.bulletin.MESSAGE_FILE = self.test_message_file

        # 既存テストデータを削除
        if os.path.exists(self.test_message_file):
            os.remove(self.test_message_file)

    def tearDown(self):
        """各テスト後のクリーンアップ"""
        # テストファイルを削除
        if os.path.exists(self.test_message_file):
            os.remove(self.test_message_file)
        # 元のパスに戻す
        self.bulletin.MESSAGE_FILE = self.original_message_file

    def test_bulletin_instantiation(self):
        """Bulletin クラスのインスタンス化テスト"""
        self.assertIsInstance(self.bulletin, Bulletin)

    def test_data_directory_created(self):
        """__init__() で data ディレクトリが作成されるか"""
        self.assertTrue(os.path.exists(os.path.dirname(self.bulletin.MESSAGE_FILE)))

    def test_load_messages_empty_file(self):
        """存在しないファイルから load_messages() を呼ぶと空リストを返すか"""
        messages = self.bulletin.load_messages()
        self.assertIsInstance(messages, list)
        self.assertEqual(len(messages), 0)

    def test_post_message_creates_file(self):
        """post_message() でファイルが作成されるか"""
        author = "テスト太郎"
        message = "これはテストメッセージです"
        self.bulletin.post_message(author, message)

        self.assertTrue(os.path.exists(self.test_message_file))

    def test_post_message_saves_correctly(self):
        """post_message() でメッセージが正しく保存されるか"""
        author = "テスト太郎"
        message = "これはテストメッセージです"
        self.bulletin.post_message(author, message)

        messages = self.bulletin.load_messages()
        self.assertEqual(len(messages), 1)
        self.assertEqual(messages[0]["author"], author)
        self.assertEqual(messages[0]["message"], message)

    def test_post_message_has_timestamp(self):
        """post_message() でタイムスタンプが付加されるか"""
        author = "テスト太郎"
        message = "これはテストメッセージです"
        self.bulletin.post_message(author, message)

        messages = self.bulletin.load_messages()
        self.assertIn("timestamp", messages[0])
        # ISO 8601 形式の確認
        try:
            datetime.fromisoformat(messages[0]["timestamp"])
        except ValueError:
            self.fail("timestamp が ISO 8601 形式ではない")

    def test_post_multiple_messages(self):
        """複数のメッセージが保存されるか"""
        messages_to_post = [
            ("ユーザー1", "メッセージ1"),
            ("ユーザー2", "メッセージ2"),
            ("ユーザー3", "メッセージ3"),
        ]

        for author, message in messages_to_post:
            self.bulletin.post_message(author, message)

        loaded_messages = self.bulletin.load_messages()
        self.assertEqual(len(loaded_messages), 3)

        for i, (author, message) in enumerate(messages_to_post):
            self.assertEqual(loaded_messages[i]["author"], author)
            self.assertEqual(loaded_messages[i]["message"], message)

    def test_get_messages(self):
        """get_messages() で投稿されたメッセージを取得できるか"""
        author = "テスト太郎"
        message = "これはテストメッセージです"
        self.bulletin.post_message(author, message)

        retrieved = self.bulletin.get_messages()
        self.assertEqual(len(retrieved), 1)
        self.assertEqual(retrieved[0]["author"], author)

    def test_get_messages_empty(self):
        """get_messages() でメッセージがない場合は空リストを返すか"""
        messages = self.bulletin.get_messages()
        self.assertIsInstance(messages, list)
        self.assertEqual(len(messages), 0)

    def test_messages_json_format(self):
        """messages.json ファイルが有効な JSON か"""
        author = "テスト太郎"
        message = "これはテストメッセージです"
        self.bulletin.post_message(author, message)

        with open(self.test_message_file, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.assertIsInstance(data, list)
        self.assertEqual(len(data), 1)

    def test_japanese_characters_preserved(self):
        """日本語文字が正しく保存されるか"""
        author = "田中太郎"
        message = "これはテストメッセージです。日本語対応を確認します。"
        self.bulletin.post_message(author, message)

        messages = self.bulletin.load_messages()
        self.assertEqual(messages[0]["author"], author)
        self.assertEqual(messages[0]["message"], message)


class TestMainIntegration(unittest.TestCase):
    """main.py の統合テスト"""

    def test_weather_import(self):
        """Weather モジュールがインポート可能か"""
        try:
            from weather import Weather
        except ImportError:
            self.fail("Weather モジュールがインポートできない")

    def test_bulletin_import(self):
        """Bulletin モジュールがインポート可能か"""
        try:
            from bulletin import Bulletin
        except ImportError:
            self.fail("Bulletin モジュールがインポートできない")

    def test_main_module_syntax(self):
        """main.py が有効な Python 構文か"""
        import py_compile
        try:
            py_compile.compile("main.py", doraise=True)
        except py_compile.PyCompileError as e:
            self.fail(f"main.py に構文エラーがある: {e}")

    def test_village_tool_class_exists(self):
        """main.py で VillageTool クラスが定義されているか"""
        from main import VillageTool
        self.assertTrue(callable(VillageTool))

    def test_village_tool_instantiation(self):
        """VillageTool クラスのインスタンス化が可能か"""
        from main import VillageTool
        tool = VillageTool()
        self.assertIsInstance(tool, VillageTool)

    def test_village_tool_has_weather(self):
        """VillageTool が Weather インスタンスを持つか"""
        from main import VillageTool
        tool = VillageTool()
        self.assertIsInstance(tool.weather, Weather)

    def test_village_tool_has_bulletin(self):
        """VillageTool が Bulletin インスタンスを持つか"""
        from main import VillageTool
        tool = VillageTool()
        self.assertIsInstance(tool.bulletin, Bulletin)

    def test_village_tool_has_required_methods(self):
        """VillageTool が必須メソッドを持つか"""
        from main import VillageTool
        tool = VillageTool()

        required_methods = [
            "display_menu",
            "run_weather",
            "run_bulletin",
            "main_loop"
        ]

        for method_name in required_methods:
            self.assertTrue(
                hasattr(tool, method_name),
                f"VillageTool に {method_name} メソッドがない"
            )
            self.assertTrue(
                callable(getattr(tool, method_name)),
                f"{method_name} がメソッドでない"
            )


def run_tests():
    """テストスイートの実行"""
    # テストローダーとランナーを作成
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # テストケースを追加
    suite.addTests(loader.loadTestsFromTestCase(TestWeather))
    suite.addTests(loader.loadTestsFromTestCase(TestBulletin))
    suite.addTests(loader.loadTestsFromTestCase(TestMainIntegration))

    # テストを実行
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    return result


if __name__ == "__main__":
    result = run_tests()
    sys.exit(0 if result.wasSuccessful() else 1)
