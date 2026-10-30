// validate-env.js
// Utility to validate the complete set of teammate environment variables for Akshaya Ahar

const fs = require('fs');
const path = require('path');

const envPath = path.join(__dirname, '.env');

console.log('====================================================');
console.log('   Akshaya Ahar - Complete Environment Check        ');
console.log('====================================================\n');

if (!fs.existsSync(envPath)) {
  console.error('❌ .env file NOT found at: ' + envPath);
  process.exit(1);
}

console.log('✅ Found .env file at: ' + envPath + '\n');

// Parse .env manually
const envContent = fs.readFileSync(envPath, 'utf8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#')) return;
  const eqIdx = trimmed.indexOf('=');
  if (eqIdx !== -1) {
    const key = trimmed.slice(0, eqIdx).trim();
    const val = trimmed.slice(eqIdx + 1).trim();
    envVars[key] = val;
  }
});

function checkVar(name, isSecret = false) {
  const val = envVars[name];
  const exists = val !== undefined && val !== null;
  const isFilled = exists && val.length > 0 && !val.startsWith('<') && !val.includes('[YOUR-');
  
  if (isFilled) {
    if (isSecret) {
      console.log(`  ✅ ${name.padEnd(35)} : [CONFIGURED] (${val.length} chars)`);
    } else {
      console.log(`  ✅ ${name.padEnd(35)} : ${val}`);
    }
  } else {
    console.log(`  ⚠️  ${name.padEnd(35)} : [MISSING OR EMPTY]`);
  }
  return isFilled;
}

console.log('--- 1. Backend & Database Configuration ---');
checkVar('PORT');
checkVar('NODE_ENV');
const dbUrlSet = checkVar('DATABASE_URL', true);
checkVar('DATABASE_SSL');
checkVar('DATABASE_SSL_CA_PATH');
const supUrlSet = checkVar('SUPABASE_URL');
const supPubKeySet = checkVar('SUPABASE_PUBLISHABLE_KEY', true);
const supSecKeySet = checkVar('SUPABASE_SECRET_KEY', true);
checkVar('VOLUNTEER_INVITE_REDIRECT_URL');
checkVar('LOCATION_RETENTION_DAYS');
checkVar('CORS_ORIGIN');

console.log('\n--- 2. Expo Frontend Configuration ---');
checkVar('EXPO_PUBLIC_API_BASE_URL');
checkVar('EXPO_PUBLIC_SUPABASE_URL');
checkVar('EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY', true);

console.log('\n--- 3. Vite Frontend Configuration ---');
checkVar('VITE_API_BASE_URL');
checkVar('VITE_SUPABASE_URL');
checkVar('VITE_SUPABASE_PUBLISHABLE_KEY', true);

// Verify SSL Path on macOS if set
if (envVars.DATABASE_SSL_CA_PATH) {
  if (fs.existsSync(envVars.DATABASE_SSL_CA_PATH)) {
    console.log(`\n  ✅ SSL CA Certificate found at: ${envVars.DATABASE_SSL_CA_PATH}`);
  } else {
    console.log(`\n  ⚠️  SSL CA Certificate file NOT found at: ${envVars.DATABASE_SSL_CA_PATH}`);
  }
}

console.log('\n====================================================');
const hasPublicUrl = supUrlSet || envVars.VITE_SUPABASE_URL || envVars.EXPO_PUBLIC_SUPABASE_URL;
const hasPubKey = supPubKeySet || envVars.VITE_SUPABASE_PUBLISHABLE_KEY || envVars.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

if (!hasPublicUrl || !hasPubKey) {
  console.log('STATUS: PENDING SUPABASE CREDENTIALS');
  console.log('Action: Please supply your rotated SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY');
  console.log('        (and SUPABASE_SECRET_KEY for server operations) in .env.');
} else {
  console.log('STATUS: Credentials detected. Ready for live database operations.');
}
console.log('====================================================\n');
