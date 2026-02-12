/**
 * Script untuk test chatbot questions
 * Run dengan: node test-chatbot-questions.js
 */

const API_URL = "https://evacuate-ai-guow.vercel.app/api/chat";

const questions = [
  {
    title: "Test 1: Kontekstual - Gempa dan Dampak",
    message:
      "Jika terjadi gempa 6.5 SR di Bandung, apa yang harus dilakukan penduduk yang tinggal di apartemen lantai 15?",
    userLocation: {
      label: "Bandung",
      lat: -6.9175,
      lng: 107.6191,
    },
  },
  {
    title: "Test 2: Prediksi dan Persiapan Cuaca",
    message:
      "Bagaimana cara mempersiapkan diri jika prakiraan menunjukkan hujan lebat selama 3 hari berturut-turut di Jakarta?",
    userLocation: {
      label: "Jakarta Pusat",
      lat: -6.2088,
      lng: 106.8456,
    },
  },
  {
    title: "Test 3: Skenario Kompleks - Banjir Malam Hari",
    message:
      "Saya sedang di rumah seorang diri malam hari dan air mulai masuk. Listrik masih menyala tapi air sudah setinggi 30cm. Apa langkah prioritas yang harus saya lakukan sekarang?",
    userLocation: {
      label: "Jakarta Selatan",
      lat: -6.2615,
      lng: 106.8106,
    },
  },
  {
    title: "Test 4: Kombinasi Bencana",
    message:
      "Bagaimana cara mengevakuasi keluarga dengan bayi dan lansia saat terjadi banjir disertai tanah longsor?",
    userLocation: {
      label: "Bogor",
      lat: -6.5971,
      lng: 106.806,
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
    const hasAIIndicators =
      data.reply.length > 300 || // AI tends to be more verbose
      data.reply.includes("dapat") ||
      data.reply.includes("sebaiknya") ||
      data.reply.includes("perlu") ||
      data.reply.includes("penting") ||
      !data.reply.match(/^Status:/); // Rule-based always starts with Status:

    if (hasAIIndicators) {
      console.log("🤖 Type: AI-Generated Response (Gemini/Groq)");
    } else {
      console.log("📋 Type: Rule-based Fallback");
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
