// Simple test runner to call the HTTPS callable function generateOfferDraft
// Requires the function to be deployed in europe-west1 on project presto-app-74abe

const REGION = 'europe-west1';
const PROJECT_ID = 'presto-app-74abe';
const FUNCTION_NAME = 'generateOfferDraft';

const endpoint = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${FUNCTION_NAME}`;

async function main() {
  const payload = {
    data: {
      hint: 'Besoin d\'un plombier pour réparer une fuite sous évier à Baie-Mahault, cette semaine. Budget raisonnable.',
      city: 'Baie-Mahault',
      category: 'Bricolage',
      lang: 'fr'
    }
  };

  console.log('Calling:', endpoint);
  const res = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  });

  if (!res.ok) {
    const text = await res.text();
    console.error('HTTP Error', res.status, text);
    process.exit(1);
  }

  const json = await res.json();
  // HTTPS callable returns { result: ... } in v2
  console.log('Raw response:', JSON.stringify(json, null, 2));
  const result = json.result || json;
  console.log('\nParsed draft:', JSON.stringify(result, null, 2));
}

main().catch((e) => {
  console.error('Test failed:', e);
  process.exit(1);
});
