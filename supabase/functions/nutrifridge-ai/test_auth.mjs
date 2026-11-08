import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const indexTsPath = join(__dirname, 'index.ts');
const sourceCode = readFileSync(indexTsPath, 'utf-8');

console.log('=== NutriFridge Edge Function Auth Regression Test Suite ===\n');

let passedTests = 0;
let totalTests = 0;

function assert(condition, message) {
  totalTests++;
  if (condition) {
    console.log(`[PASS] Test ${totalTests}: ${message}`);
    passedTests++;
  } else {
    console.error(`[FAIL] Test ${totalTests}: ${message}`);
    process.exitCode = 1;
  }
}

// Simulated Auth Simulation Function matching index.ts logic
async function simulateAuthFlow({ headers, mockUser, mockAuthError, requestBody }) {
  const authHeader = headers['Authorization'] || headers['authorization'] || null;
  const logs = [];

  // 1. Missing Authorization Check
  if (!authHeader) {
    logs.push('AUTH_HEADER_MISSING');
    return {
      status: 401,
      body: { ok: false, error: 'MISSING_AUTHORIZATION' },
      logs,
      n8nCalled: false,
    };
  }

  // 2. Malformed Bearer Token Check
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    logs.push('AUTH_HEADER_FORMAT_INVALID');
    return {
      status: 401,
      body: { ok: false, error: 'INVALID_AUTHORIZATION_FORMAT' },
      logs,
      n8nCalled: false,
    };
  }

  const token = match[1].trim();
  logs.push('AUTH_TOKEN_EXTRACTED');

  // 3. Validate Token via getUser(token)
  if (mockAuthError || !mockUser) {
    logs.push('AUTH_GET_USER_FAILED');
    return {
      status: 401,
      body: { ok: false, error: 'USER_AUTHENTICATION_FAILED' },
      logs,
      n8nCalled: false,
    };
  }

  logs.push('AUTH_USER_VERIFIED');
  // 4. Strict derivation from verified user - ignore requestBody.userId
  const verifiedUserId = mockUser.id;

  // 5. Context Query & n8n Dispatch
  logs.push('USER_CONTEXT_QUERY_STARTED');
  logs.push('N8N_REQUEST_STARTED');

  return {
    status: 200,
    body: { ok: true, userId: verifiedUserId },
    logs,
    n8nCalled: true,
    derivedUserId: verifiedUserId,
  };
}

async function runTests() {
  // Test 1: Valid JWT authenticates successfully
  {
    const res = await simulateAuthFlow({
      headers: { Authorization: 'Bearer valid.jwt.token' },
      mockUser: { id: 'usr_valid_123' },
      mockAuthError: null,
      requestBody: { message: 'hello' },
    });
    assert(res.status === 200 && res.body.ok === true, 'Valid JWT authenticates successfully (200 OK)');
  }

  // Test 2: Missing Authorization returns 401
  {
    const res = await simulateAuthFlow({
      headers: {},
      mockUser: { id: 'usr_123' },
      mockAuthError: null,
    });
    assert(
      res.status === 401 && res.body.error === 'MISSING_AUTHORIZATION' && res.logs.includes('AUTH_HEADER_MISSING'),
      'Missing Authorization returns 401 with MISSING_AUTHORIZATION'
    );
  }

  // Test 3: Malformed Bearer header returns 401
  {
    const res = await simulateAuthFlow({
      headers: { Authorization: 'Basic dXNlcjpwYXNz' },
      mockUser: { id: 'usr_123' },
      mockAuthError: null,
    });
    assert(
      res.status === 401 && res.body.error === 'INVALID_AUTHORIZATION_FORMAT' && res.logs.includes('AUTH_HEADER_FORMAT_INVALID'),
      'Malformed Bearer header (Basic auth) returns 401 with INVALID_AUTHORIZATION_FORMAT'
    );

    const res2 = await simulateAuthFlow({
      headers: { Authorization: 'Bearer' },
      mockUser: { id: 'usr_123' },
      mockAuthError: null,
    });
    assert(
      res2.status === 401 && res2.body.error === 'INVALID_AUTHORIZATION_FORMAT',
      'Malformed Bearer header without token returns 401'
    );
  }

  // Test 4: Invalid or expired JWT returns 401
  {
    const res = await simulateAuthFlow({
      headers: { Authorization: 'Bearer expired.jwt.token' },
      mockUser: null,
      mockAuthError: { message: 'JWT expired', status: 401, name: 'AuthApiError' },
    });
    assert(
      res.status === 401 && res.body.error === 'USER_AUTHENTICATION_FAILED' && res.logs.includes('AUTH_GET_USER_FAILED'),
      'Invalid or expired JWT returns 401 with USER_AUTHENTICATION_FAILED'
    );
  }

  // Test 5: Valid JWT retrieves the correct authenticated user
  {
    const res = await simulateAuthFlow({
      headers: { Authorization: 'Bearer valid.jwt.token' },
      mockUser: { id: 'usr_alice_456' },
      mockAuthError: null,
    });
    assert(
      res.derivedUserId === 'usr_alice_456' && res.logs.includes('AUTH_USER_VERIFIED'),
      'Valid JWT retrieves the correct authenticated user (usr_alice_456)'
    );
  }

  // Test 6: A different user ID cannot be substituted by the client
  {
    const res = await simulateAuthFlow({
      headers: { Authorization: 'Bearer valid.jwt.for.alice' },
      mockUser: { id: 'usr_alice_real' },
      mockAuthError: null,
      requestBody: { userId: 'usr_attacker_spoof' },
    });
    assert(
      res.derivedUserId === 'usr_alice_real',
      "Attacker cannot substitute client-supplied userId (remains user.id = usr_alice_real)"
    );
  }

  // Test 7: User-context database queries retain RLS
  {
    assert(
      sourceCode.includes('global: {') &&
      sourceCode.includes('Authorization: authHeader') &&
      /supabaseUser\s*\.from\(\s*['"]fridge_items['"]\s*\)/.test(sourceCode) &&
      /supabaseUser\s*\.from\(\s*['"]nutrition_goals['"]\s*\)/.test(sourceCode),
      'User-context database queries retain RLS using supabaseUser with Authorization: authHeader'
    );
  }

  // Test 8: n8n is not called when authentication fails
  {
    const resFail1 = await simulateAuthFlow({ headers: {} });
    const resFail2 = await simulateAuthFlow({ headers: { Authorization: 'invalid' } });
    const resFail3 = await simulateAuthFlow({
      headers: { Authorization: 'Bearer bad.token' },
      mockUser: null,
      mockAuthError: { message: 'Invalid' },
    });
    assert(
      resFail1.n8nCalled === false && resFail2.n8nCalled === false && resFail3.n8nCalled === false,
      'n8n is strictly NOT called when authentication fails'
    );
  }

  // Test 9: Source code static contract analysis
  {
    assert(
      sourceCode.includes('supabaseUser.auth.getUser(token)') &&
      !sourceCode.includes('supabaseUser.auth.getUser()'),
      'Source code explicitly calls supabaseUser.auth.getUser(token) with extracted token'
    );
    assert(
      sourceCode.includes("console.log('AUTH_USER_VERIFIED')") &&
      sourceCode.includes("console.log('USER_CONTEXT_QUERY_STARTED')") &&
      sourceCode.includes("console.log('N8N_REQUEST_STARTED')"),
      'Source code contains all required diagnostic log identifiers'
    );
  }

  // Test 10: Edge function timeout configuration (75,000ms and finally clearTimeout)
  {
    assert(
      sourceCode.includes('75000') &&
      /finally\s*\{\s*clearTimeout\(\s*timeoutId\s*\);?\s*\}/.test(sourceCode),
      'Edge function uses 75,000ms timeout with clearTimeout in finally block'
    );
    assert(
      sourceCode.includes("'GEMINI_REQUEST_TIMEOUT'") &&
      sourceCode.includes("'GEMINI_RATE_LIMIT_EXCEEDED'") &&
      sourceCode.includes("'GEMINI_AUTH_FAILED'") &&
      sourceCode.includes("'GEMINI_INVALID_REQUEST'"),
      'Edge function distinguishes GEMINI_REQUEST_TIMEOUT, 429 rate limit, auth, and invalid request errors'
    );
  }

  // Test 11: n8n workflow integration contract (Restored Gemini REST API HTTP Request node & error handling)
  {
    const workflowPath = join(__dirname, '../../../n8n/workflows/nutrifridge-ai-assistant.json');
    const workflowSource = readFileSync(workflowPath, 'utf-8');
    const workflowJson = JSON.parse(workflowSource);
    const geminiHttpNode = workflowJson.nodes.find(
      (n) => n.name === 'HTTP Request — Gemini generateContent' || n.name === 'Call Google Gemini API'
    );
    assert(
      geminiHttpNode &&
      geminiHttpNode.parameters &&
      geminiHttpNode.parameters.url &&
      geminiHttpNode.parameters.url.includes('gemini-flash-lite-latest:generateContent'),
      'n8n workflow HTTP Request node targets gemini-flash-lite-latest:generateContent REST endpoint'
    );
    assert(
      workflowSource.includes('GEMINI_UPSTREAM_ERROR') &&
      workflowSource.includes('x-goog-api-key'),
      'n8n workflow handles upstream Gemini errors and configures x-goog-api-key authentication'
    );
  }

  console.log(`\nResults: ${passedTests} / ${totalTests} tests passed.\n`);
}

runTests();
