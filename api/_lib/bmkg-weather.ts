/**
 * BMKG Weather Forecast Integration
 * API: https://api.bmkg.go.id/publik/prakiraan-cuaca
 * 3-day forecasts, 8 data points/day (3-hour intervals)
 */

export interface WeatherForecastDay {
  date: string;
  tempMin: number;
  tempMax: number;
  weather: string;
  rainProbability: number;
}

export interface WeatherForecastSummary {
  location: string;
  days: WeatherForecastDay[];
  source: "BMKG";
}

// Location to admin code mapping (adm4)
const LOCATION_CODES: Record<string, string> = {
  "jakarta pusat": "31.71.03.1001",
  "jakarta selatan": "31.74.01.1001",
  "jakarta utara": "31.72.01.1001",
  "jakarta barat": "31.73.01.1001",
  "jakarta timur": "31.75.01.1001",
  bandung: "32.73.01.1001",
  bekasi: "32.75.01.1001",
  bogor: "32.71.01.1001",
  depok: "32.76.01.1001",
  semarang: "33.74.01.1001",
  surabaya: "35.78.01.1001",
  yogyakarta: "34.71.01.1001",
};

export async function fetchWeatherForecast(
  location: string,
): Promise<WeatherForecastSummary | null> {
  try {
    const code = findCode(location);
    if (!code) return null;

    const url = `https://api.bmkg.go.id/publik/prakiraan-cuaca?adm4=${code}`;
    const response = await fetch(url, {
      headers: { accept: "application/json" },
    });

    if (!response.ok) return null;

    const data = await response.json();
    return parseResponse(data, location);
  } catch (error) {
    console.error("Weather fetch error:", error);
    return null;
  }
}

function findCode(location: string): string | null {
  const norm = location.toLowerCase().trim();
  if (LOCATION_CODES[norm]) return LOCATION_CODES[norm];

  for (const [key, code] of Object.entries(LOCATION_CODES)) {
    if (norm.includes(key) || key.includes(norm)) return code;
  }
  return null;
}

function parseResponse(
  data: any,
  location: string,
): WeatherForecastSummary | null {
  try {
    const weatherData = data?.data?.[0];
    if (!weatherData) return null;

    const days: WeatherForecastDay[] = [];
    const cuacaArrays = weatherData.cuaca || [];

    for (const dayData of cuacaArrays.slice(0, 3)) {
      if (!Array.isArray(dayData)) continue;

      let tempMin = Infinity;
      let tempMax = -Infinity;
      let rainCount = 0;
      let midWeather = "";

      dayData.forEach((hour, idx) => {
        const temp = Number(hour.t) || 0;
        tempMin = Math.min(tempMin, temp);
        tempMax = Math.max(tempMax, temp);

        const weather = (hour.weather_desc || "").toLowerCase();
        if (weather.includes("hujan")) rainCount++;
        if (idx === Math.floor(dayData.length / 2)) {
          midWeather = hour.weather_desc || "Berawan";
        }
      });

      const firstHour = dayData[0];
      days.push({
        date: firstHour?.local_datetime?.split(" ")[0] || "",
        tempMin: Math.round(tempMin),
        tempMax: Math.round(tempMax),
        weather: midWeather,
        rainProbability: Math.round((rainCount / dayData.length) * 100),
      });
    }

    return { location, days, source: "BMKG" };
  } catch (error) {
    return null;
  }
}
