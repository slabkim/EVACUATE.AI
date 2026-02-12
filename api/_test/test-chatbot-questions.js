/**
 * Script untuk test chatbot questions
 * Run dengan: node test-chatbot-questions.js
 */

const API_URL = "https://evacuate-ai-guow.vercel.app/api/chat";

const questions = [
  {
    title: "Test 1: Gempa Terbaru",
    message: "Gempa terbaru di mana?",
    latestEarthquake: {
      magnitude: 5.3,
      depthKm: 10,
      wilayah: "Jawa Barat",
      dateTime: new Date().toISOString(),
      eqLat: -6.5,
      eqLng: 107.0,
      potensi: "Tidak berpotensi tsunami",
    },
  },
  {
    title: "Test 2: Prakiraan Cuaca",
    message: "Bagaimana cuaca besok di Jakarta?",
    userLocation: {
      label: "Jakarta Pusat",
      lat: -6.2088,
      lng: 106.8456,
    },
  },
  {
    title: "Test 3: Evakuasi Banjir",
    message: "Cara evakuasi saat banjir?",
    userLocation: {
      label: "Jakarta Selatan",
      lat: -6.2615,
      lng: 106.8106,
    },
  },
];

async function testQuestion(question) {
  console.log(`\n${"=".repeat(60)}`);
  console.log(`📝 ${question.title}`);
  console.log(`❓ Pertanyaan: "${question.message}"`);
  console.log(`${"=".repeat(60)}\n`);

  try {
    const response = await fetch(API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: question.message,
        latestEarthquake: question.latestEarthquake,
        userLocation: question.userLocation,
        history: [],
      }),
    });

    if (!response.ok) {
      console.error(`❌ HTTP Error: ${response.status} ${response.statusText}`);
      const errorText = await response.text();
      console.error(`Error details: ${errorText}`);
      return;
    }

    const data = await response.json();

    console.log("✅ Response received:\n");
    console.log(data.reply);
    console.log("\n");

    // Analyze response type
    if (data.reply.includes("Gemini") || data.reply.includes("AI")) {
      console.log("🤖 Type: Likely Gemini AI response (contextual)");
    } else if (
      data.reply.includes("Status:") &&
      data.reply.includes("Sumber:")
    ) {
      console.log("📋 Type: Structured response (could be AI or rule-based)");
    } else {
      console.log("⚙️ Type: Rule-based fallback");
    }
  } catch (error) {
    console.error(`❌ Error: ${error.message}`);
  }
}

async function runAllTests() {
  console.log("\n🚀 Starting Chatbot Tests...\n");

  for (const question of questions) {
    await testQuestion(question);
    // Wait a bit between requests
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  console.log(`\n${"=".repeat(60)}`);
  console.log("✅ All tests completed!");
  console.log(`${"=".repeat(60)}\n`);
}

// Run tests
runAllTests().catch(console.error);
