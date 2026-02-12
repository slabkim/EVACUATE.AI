import { generateEarthquakeReply } from "../_lib/llm";

/**
 * Test script untuk memverifikasi:
 * 1. Gemini API functionality
 * 2. OpenAI API functionality
 * 3. Fallback mechanism Gemini → OpenAI
 * 4. Response quality dan formatting
 */

async function main() {
  console.log("=== Test LLM Providers ===\n");

  const testMessage =
    "Bagaimana cara evakuasi saat gempa di gedung bertingkat?";
  const userLocation = {
    label: "Jakarta Selatan",
    lat: -6.2615,
    lng: 106.8106,
  };

  const latestEarthquake = {
    magnitude: 5.3,
    depthKm: 10,
    wilayah: "Jawa Barat",
    dateTime: new Date().toISOString(),
    eqLat: -6.5,
    eqLng: 107.0,
  };

  // Test 1: Check environment variables
  console.log("📋 Environment Variables:");
  console.log(
    `  GEMINI_API_KEY: ${process.env.GEMINI_API_KEY ? "✓ Set" : "✗ Not set"}`,
  );
  console.log(
    `  OPENAI_API_KEY: ${process.env.OPENAI_API_KEY ? "✓ Set" : "✗ Not set"}`,
  );
  console.log("");

  // Test 2: Normal request (should use Gemini if available)
  console.log("🧪 Test 1: Normal Request (Primary Provider)");
  try {
    const startTime = Date.now();
    const response = await generateEarthquakeReply({
      message: testMessage,
      userLocation,
      latestEarthquake,
    });
    const duration = Date.now() - startTime;

    console.log(`  ⏱️ Response time: ${duration}ms`);
    console.log(`  📝 Response preview:`);
    console.log(`     ${response.split("\n")[0]}`);
    console.log(`     ${response.split("\n")[1]}`);
    console.log(`  ✅ Success\n`);
  } catch (error) {
    console.error(`  ❌ Failed: ${error}\n`);
  }

  // Test 3: OpenAI-specific test (if available)
  if (process.env.OPENAI_API_KEY) {
    console.log("🧪 Test 2: OpenAI Provider (with Gemini disabled)");
    const originalGeminiKey = process.env.GEMINI_API_KEY;
    process.env.GEMINI_API_KEY = ""; // Temporarily disable Gemini

    try {
      const startTime = Date.now();
      const response = await generateEarthquakeReply({
        message: "Apa yang harus dilakukan jika terjadi tsunami?",
        userLocation,
      });
      const duration = Date.now() - startTime;

      console.log(`  ⏱️ Response time: ${duration}ms`);
      console.log(`  📝 Response preview:`);
      console.log(`     ${response.split("\n")[0]}`);
      console.log(`     ${response.split("\n")[1]}`);
      console.log(`  ✅ OpenAI fallback working\n`);
    } catch (error) {
      console.error(`  ❌ Failed: ${error}\n`);
    } finally {
      process.env.GEMINI_API_KEY = originalGeminiKey; // Restore
    }
  }

  // Test 4: Fallback to rule-based (both providers disabled)
  console.log("🧪 Test 3: Rule-based Fallback (all providers disabled)");
  const originalGeminiKey = process.env.GEMINI_API_KEY;
  const originalOpenAIKey = process.env.OPENAI_API_KEY;
  process.env.GEMINI_API_KEY = "";
  process.env.OPENAI_API_KEY = "";

  try {
    const startTime = Date.now();
    const response = await generateEarthquakeReply({
      message: "Cara evakuasi banjir?",
      userLocation,
    });
    const duration = Date.now() - startTime;

    console.log(`  ⏱️ Response time: ${duration}ms`);
    console.log(`  📝 Response preview:`);
    console.log(`     ${response.split("\n")[0]}`);
    console.log(`     ${response.split("\n")[1]}`);
    console.log(`  ✅ Rule-based fallback working\n`);
  } catch (error) {
    console.error(`  ❌ Failed: ${error}\n`);
  } finally {
    process.env.GEMINI_API_KEY = originalGeminiKey;
    process.env.OPENAI_API_KEY = originalOpenAIKey;
  }

  // Test 5: Response formatting validation
  console.log("🧪 Test 4: Response Format Validation");
  try {
    const response = await generateEarthquakeReply({
      message: "Gempa terbaru di mana?",
      latestEarthquake,
    });

    const hasStatus = /status\s*:/i.test(response);
    const hasSource = /sumber\s*:/i.test(response);
    const hasSteps = /langkah/i.test(response);

    console.log(`  Status field: ${hasStatus ? "✅" : "❌"}`);
    console.log(`  Source attribution: ${hasSource ? "✅" : "❌"}`);
    console.log(`  Structured steps: ${hasSteps ? "✅" : "❌"}`);
    console.log("");
  } catch (error) {
    console.error(`  ❌ Failed: ${error}\n`);
  }

  console.log("=== Test Complete ===");
}

main().catch(console.error);
