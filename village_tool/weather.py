"""
天気予報モジュール

このモジュールは、架空の天気予報を生成・管理する。
ランダムな気象パターンと気温を提供する。
"""

import random


class Weather:
    """
    天気予報クラス

    指定された都市名に対して、架空の天気と気温を生成する。
    """

    # 利用可能な天気パターン
    WEATHER_PATTERNS = [
        "晴れ",
        "曇り",
        "雨",
        "雪",
        "嵐"
    ]

    # 気温の範囲
    MIN_TEMPERATURE = -10
    MAX_TEMPERATURE = 35

    def __init__(self):
        """初期化処理"""
        pass

    def get_random_weather(self):
        """
        ランダムな天気を生成

        Returns:
            str: 天気パターンの文字列
        """
        return random.choice(self.WEATHER_PATTERNS)

    def get_random_temperature(self):
        """
        ランダムな気温を生成

        Returns:
            int: -10℃ ～ 35℃ の範囲のランダムな気温
        """
        return random.randint(self.MIN_TEMPERATURE, self.MAX_TEMPERATURE)

    def forecast(self, city_name):
        """
        指定した都市の天気予報を生成

        Args:
            city_name (str): 都市名

        Returns:
            dict: 天気予報情報を含む辞書
                {
                    "city": city_name,
                    "weather": 天気,
                    "temperature": 気温
                }
        """
        return {
            "city": city_name,
            "weather": self.get_random_weather(),
            "temperature": self.get_random_temperature()
        }

    def display_forecast(self, forecast_data):
        """
        天気予報の表示

        Args:
            forecast_data (dict): forecast() メソッドが返す辞書
        """
        city = forecast_data["city"]
        weather = forecast_data["weather"]
        temperature = forecast_data["temperature"]
        print(f"\n{city}の天気: {weather}, 気温: {temperature}℃")
