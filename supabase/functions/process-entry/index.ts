// Supabase Edge Function: process-entry
// Receives a raw speech-to-text transcript (and optionally an audio file path
// in Supabase Storage), corrects recognition errors, formats as clean bullet
// points, generates a title, picks the best existing category (or creates one),
// and stores the entry.
//
// When audio_path is provided the function downloads the file from the "audio"
// bucket and re-transcribes it with OpenAI Whisper. The Whisper transcript is
// used as the primary input (more accurate than on-device Apple STT).
//
// A DB trigger on `entries` auto-manages category `entry_count`,
// `latest_entry_title`, and `last_updated`. No manual count management here.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const MAX_TRANSCRIPT_LENGTH = 10000;
const OPENAI_TIMEOUT_MS = 25000;
const WHISPER_TIMEOUT_MS = 60000;
const MAX_AI_CATEGORIES = 10;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

interface LLMResult {
  formatted_transcript: string;
  title: string;
  category: string;
  is_explicit_placement: boolean;
  confidence_score: number;
  category_reason: string;
  suggested_new_category?: string;
  new_category_explanation?: string;
}

type SupabaseClient = ReturnType<typeof createClient>;

// --- Shared helpers ---

function parseCentroid(raw: unknown): number[] | null {
  if (!raw) return null;
  if (Array.isArray(raw)) return raw as number[];
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw) as number[];
    } catch {
      return null;
    }
  }
  return null;
}

// Running-average centroid update. Called BEFORE entry insert (count is still old value).
async function updateCentroid(
  supabase: SupabaseClient,
  categoryId: string,
  newEmbedding: number[],
): Promise<void> {
  const { data: cat } = await supabase
    .from('categories')
    .select('embedding_centroid, entry_count')
    .eq('id', categoryId)
    .single();

  if (!cat) return;

  const old = parseCentroid(cat.embedding_centroid);
  const n = cat.entry_count;
  const centroid = old
    ? old.map((v: number, i: number) => (v * n + newEmbedding[i]) / (n + 1))
    : newEmbedding;

  await supabase
    .from('categories')
    .update({ embedding_centroid: centroid })
    .eq('id', categoryId);
}

async function createNewCategory(
  supabase: SupabaseClient,
  userId: string,
  name: string,
  embedding: number[],
): Promise<string> {
  const { data, error } = await supabase
    .from('categories')
    .insert({
      user_id: userId,
      name,
      embedding_centroid: embedding,
      entry_count: 0, // trigger increments on entry insert
    })
    .select()
    .single();

  if (error || !data)
    throw new Error(`Failed to create category: ${error?.message}`);
  return data.id;
}

async function forceAssignToClosest(
  supabase: SupabaseClient,
  embedding: number[],
  userId: string,
  fallbackId: string,
): Promise<string> {
  const { data } = await supabase.rpc('match_category', {
    query_embedding: embedding,
    match_user_id: userId,
    match_threshold: 0.0,
  });
  return data?.[0]?.id ?? fallbackId;
}

/** Levenshtein edit distance between two strings. */
function levenshtein(a: string, b: string): number {
  const m = a.length;
  const n = b.length;
  const dp: number[][] = Array.from({ length: m + 1 }, (_, i) =>
    Array.from({ length: n + 1 }, (_, j) => (i === 0 ? j : j === 0 ? i : 0)),
  );
  for (let i = 1; i <= m; i++)
    for (let j = 1; j <= n; j++)
      dp[i][j] =
        a[i - 1] === b[j - 1]
          ? dp[i - 1][j - 1]
          : 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
  return dp[m][n];
}

/** Fuzzy name match: handles "Health" vs "Health & Fitness", "Finance" vs "Finances", etc. */
function fuzzyMatchCategory(
  llmName: string,
  cats: { id: string; name: string }[],
): { id: string; name: string } | undefined {
  const toWords = (s: string) =>
    s
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, '')
      .trim()
      .split(/\s+/)
      .filter(Boolean);
  const suggestedWords = toWords(llmName);
  if (suggestedWords.length === 0) return undefined;

  // 1. Exact normalized match (ignoring punctuation & case)
  const suggestedKey = suggestedWords.join(' ');
  const exact = cats.find((c) => toWords(c.name).join(' ') === suggestedKey);
  if (exact) return exact;

  // 2. Word-level containment: all words of the shorter name appear in the longer one.
  //    "Health" matches "Health & Fitness" (health ⊂ {health, fitness}), but
  //    "Work" does NOT match "Workout" (different words after splitting).
  const wordMatch = cats.find((c) => {
    const catWords = toWords(c.name);
    const [shorter, longer] =
      suggestedWords.length <= catWords.length
        ? [suggestedWords, catWords]
        : [catWords, suggestedWords];
    return shorter.every((w) => longer.includes(w));
  });
  if (wordMatch) return wordMatch;

  // 3. Edit-distance match: catches plurals, typos, and minor spelling variations.
  //    "Finance" matches "Finances", "Travell" matches "Travel", etc.
  //    Only matches if the edit distance is at most 2 AND less than 30% of the name length.
  const closeMatch = cats.find((c) => {
    const catKey = toWords(c.name).join(' ');
    const dist = levenshtein(suggestedKey, catKey);
    const maxLen = Math.max(suggestedKey.length, catKey.length, 1);
    return dist <= 2 && dist / maxLen < 0.3;
  });
  if (closeMatch) return closeMatch;

  return undefined;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// --- Whisper transcription ---

async function transcribeWithWhisper(
  supabase: SupabaseClient,
  audioPath: string,
  lang: string,
): Promise<string> {
  // Download audio from Supabase Storage
  const { data: fileData, error: downloadError } = await supabase.storage
    .from('audio')
    .download(audioPath);

  if (downloadError || !fileData) {
    throw new Error(
      `Failed to download audio: ${downloadError?.message ?? 'no data'}`,
    );
  }

  // Map locale codes (e.g. "en-US") to ISO 639-1 for Whisper
  const langCode = lang.split('-')[0] || 'en';

  // Send to OpenAI Whisper API
  const formData = new FormData();
  formData.append('file', fileData, 'recording.m4a');
  formData.append('model', 'whisper-1');
  formData.append('language', langCode);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), WHISPER_TIMEOUT_MS);
  try {
    const response = await fetch(
      'https://api.openai.com/v1/audio/transcriptions',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
        },
        body: formData,
        signal: controller.signal,
      },
    );
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(
        `Whisper API error: ${response.status} - ${errorText}`,
      );
    }
    const result = await response.json();
    return result.text;
  } finally {
    clearTimeout(timeout);
  }
}

// --- Main handler ---

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader)
      return jsonResponse({ error: 'Missing authorization' }, 401);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const token = authHeader.replace('Bearer ', '');
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return jsonResponse(
        { error: 'Invalid token', detail: authError?.message },
        401,
      );
    }

    const {
      transcript: appleTranscript,
      category_id: manualCategoryId,
      locale,
      audio_path: audioPath,
    } = await req.json();
    const lang = typeof locale === 'string' && locale ? locale : 'en';

    // Re-transcribe with Whisper if audio is available
    let transcript: string;
    let audioUrl: string | null = null;

    if (audioPath && typeof audioPath === 'string') {
      try {
        transcript = await transcribeWithWhisper(supabase, audioPath, lang);
        audioUrl = audioPath;
      } catch (whisperErr) {
        console.error('Whisper transcription failed, falling back to Apple transcript:', whisperErr);
        transcript = appleTranscript;
      }
    } else {
      transcript = appleTranscript;
    }

    if ((!transcript || typeof transcript !== 'string') && (!appleTranscript || typeof appleTranscript !== 'string')) {
      return jsonResponse({ error: 'Missing transcript' }, 400);
    }
    // Fall back to Apple transcript if Whisper returned empty
    if (!transcript || transcript.trim().length === 0) {
      transcript = appleTranscript;
    }
    if (!transcript || typeof transcript !== 'string' || transcript.trim().length === 0) {
      return jsonResponse({ error: 'No speech detected' }, 400);
    }
    if (transcript.length > MAX_TRANSCRIPT_LENGTH) {
      return jsonResponse({ error: 'Transcript too long' }, 400);
    }

    // --- Manual note path: caller already chose the category ---
    if (manualCategoryId) {
      const title = await generateTitle(transcript, lang);
      const embedding = await generateEmbedding(transcript);
      await updateCentroid(supabase, manualCategoryId, embedding);

      const { data: entry, error: entryError } = await supabase
        .from('entries')
        .insert({
          user_id: user.id,
          transcript,
          title,
          category_id: manualCategoryId,
          embedding_vector: embedding,
          locale: lang,
          audio_url: audioUrl,
        })
        .select()
        .single();
      if (entryError || !entry)
        throw new Error(`Failed to insert entry: ${entryError?.message}`);

      const { data: category } = await supabase
        .from('categories')
        .select('*')
        .eq('id', manualCategoryId)
        .single();

      return jsonResponse({ entry, category, is_new_category: false });
    }

    // --- Normal AI categorization path ---
    const { data: existingCategories } = await supabase
      .from('categories')
      .select('id, name, embedding_centroid, entry_count, latest_entry_title')
      .eq('user_id', user.id)
      .eq('is_archived', false)
      .order('entry_count', { ascending: false });

    const cats = existingCategories ?? [];
    const categoryCount = cats.length;

    // Build category info list with recent entry titles for better LLM context.
    const categoryInfo = cats.map(
      (c: { name: string; latest_entry_title?: string }) => ({
        name: c.name,
        recentEntry: c.latest_entry_title ?? null,
      }),
    );

    const llmResult = await classifyTranscript(
      transcript,
      categoryInfo,
      lang,
    );
    const formattedTranscript = llmResult.formatted_transcript || transcript;
    const embedding = await generateEmbedding(formattedTranscript);

    // Resolve category — try name match first, then embedding similarity, then create new.
    let categoryId: string;
    let isNewCategory = false;

    // Step 1: Fuzzy name match (handles "Health" vs "Health & Fitness", etc.)
    const matched = fuzzyMatchCategory(llmResult.category, cats);
    if (matched) {
      categoryId = matched.id;
      await updateCentroid(supabase, categoryId, embedding);
    } else if (!llmResult.is_explicit_placement && cats.length > 0) {
      // Step 2: LLM suggested a new name — verify with embedding similarity.
      const { data: sim } = await supabase.rpc('match_category', {
        query_embedding: embedding,
        match_user_id: user.id,
        match_threshold: 0.60,
      });
      if (sim?.[0]?.similarity >= 0.60) {
        categoryId = sim[0].id;
        await updateCentroid(supabase, categoryId, embedding);
      } else if (categoryCount >= MAX_AI_CATEGORIES) {
        categoryId = await forceAssignToClosest(
          supabase,
          embedding,
          user.id,
          cats[0].id,
        );
        await updateCentroid(supabase, categoryId, embedding);
      } else {
        categoryId = await createNewCategory(
          supabase,
          user.id,
          llmResult.category,
          embedding,
        );
        isNewCategory = true;
      }
    } else if (categoryCount >= MAX_AI_CATEGORIES && cats.length > 0) {
      categoryId = await forceAssignToClosest(
        supabase,
        embedding,
        user.id,
        cats[0].id,
      );
      await updateCentroid(supabase, categoryId, embedding);
    } else {
      categoryId = await createNewCategory(
        supabase,
        user.id,
        llmResult.category,
        embedding,
      );
      isNewCategory = true;
    }

    // Insert entry (trigger auto-updates category stats)
    const { data: entry, error: entryError } = await supabase
      .from('entries')
      .insert({
        user_id: user.id,
        transcript: formattedTranscript,
        title: llmResult.title,
        category_id: categoryId,
        embedding_vector: embedding,
        locale: lang,
        audio_url: audioUrl,
      })
      .select()
      .single();
    if (entryError || !entry)
      throw new Error(`Failed to insert entry: ${entryError?.message}`);

    const { data: category } = await supabase
      .from('categories')
      .select('*')
      .eq('id', categoryId)
      .single();

    return jsonResponse({ entry, category, is_new_category: isNewCategory });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('process-entry error:', message);
    return jsonResponse({ error: message }, 500);
  }
});

// --- OpenAI API calls (all with timeout) ---

async function fetchWithTimeout(
  url: string,
  options: RequestInit,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), OPENAI_TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    });
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`OpenAI API error: ${response.status} - ${errorText}`);
    }
    return response;
  } finally {
    clearTimeout(timeout);
  }
}

async function classifyTranscript(
  transcript: string,
  existingCategories: { name: string; recentEntry: string | null }[],
  lang: string = 'en',
): Promise<LLMResult> {
  // Include latest entry titles so the LLM can better understand what each category contains.
  const categoriesList =
    existingCategories.length > 0
      ? existingCategories
          .map((c) =>
            c.recentEntry
              ? `- ${c.name} (recent note: "${c.recentEntry}")`
              : `- ${c.name}`,
          )
          .join('\n')
      : '(none yet)';

  const categoryCount = existingCategories.length;
  const atCap = categoryCount >= 10;

  const response = await fetchWithTimeout(
    'https://api.openai.com/v1/chat/completions',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        max_tokens: 2048,
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content: `You process voice notes from a speech-to-text system. The transcript may contain recognition errors, missing punctuation, or broken grammar. You must categorize the note, clean the transcript, and generate a title. Return ONLY valid JSON.

The user's language is "${lang}". All output must be in this language.

TASK 1 — CATEGORY (MOST IMPORTANT — do this first):
You are a smart voice-note categorization assistant. Your primary job is to analyze the user's voice note and assign it to the best topic category.
- The user may say "put this under Travel", "add to Work", etc. If so, use EXACTLY that name as the category and set is_explicit_placement to true. Strip that instruction from formatted_transcript.
- Otherwise, analyze the note deeply and assign the BEST-fitting category:
  1. First, try to fit into an existing category from the list below using deep semantic understanding — not just keyword matching. Weight context, intent, and subject matter.
  2. If an existing category clearly fits, use it and explain why in "category_reason" (1-3 sentences).
  3. If the topic is genuinely distinct and none of the existing categories are a good fit, suggest a short new category name (1-2 words, simple and broad). Put the new name in BOTH "category" and "suggested_new_category", and explain why in "new_category_explanation".
  4. Only create a new category when the topic is truly distinct — not for minor variations of existing topics.
- Provide a confidence_score (0.00-1.00) for your category assignment.${atCap ? '\n- IMPORTANT: 10 categories (maximum) reached. You MUST pick from the existing list. Do NOT suggest a new category name.' : categoryCount >= 7 ? `\n- The user has ${categoryCount}/10 categories. Prefer existing ones when the topic fits, but you can still suggest a new one if nothing fits.` : ''}

TASK 2 — CLEAN TRANSCRIPT:
- Fix punctuation, capitalization, and sentence structure.
- Correct obvious speech recognition errors using context (e.g. "I want to by a car" → "I want to buy a car").
- Fix homophones and misheard words when the intended meaning is clear.
- Remove filler words ("um", "uh", "like", repeated words) only when they add no meaning.
- Preserve the user's original meaning exactly. Do NOT rephrase, summarize, or add information.
- Format as a markdown bullet list using ONLY "- " (dash + space) prefix. Rules for splitting into bullets:
  * Each distinct thought, idea, or piece of information becomes its own bullet.
  * Topic shifts ("also", "another thing", "oh and", "by the way") start a new bullet.
  * Listed items ("I need milk, eggs, and bread") get one bullet per item.
- Do NOT use checkboxes, blockquotes, bold, italic, headings, or any other markdown syntax. ONLY "- " bullets.
- Example: "- Call the dentist tomorrow\\n- Mom's birthday is next Friday\\n- Check out the new Italian restaurant downtown"

TASK 3 — TITLE:
- Generate a short title (3-7 words) that captures the main theme.
- If the user gives a placement instruction (e.g. "put this under Travel"), strip that instruction from the title.`,
          },
          {
            role: 'user',
            content: `Existing categories:
${categoriesList}

Raw speech-to-text transcript:
"${transcript}"

Return JSON: { "formatted_transcript": "...", "title": "...", "category": "...", "is_explicit_placement": true/false, "confidence_score": 0.00, "category_reason": "...", "suggested_new_category": "..." or null, "new_category_explanation": "..." or null }`,
          },
        ],
      }),
    },
  );

  const data = await response.json();
  return JSON.parse(data.choices[0].message.content) as LLMResult;
}

async function generateTitle(
  transcript: string,
  lang: string = 'en',
): Promise<string> {
  const response = await fetchWithTimeout(
    'https://api.openai.com/v1/chat/completions',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        max_tokens: 60,
        messages: [
          {
            role: 'system',
            content: `Generate a short title (3-7 words) for this note in the "${lang}" language. Return ONLY the title text, nothing else.`,
          },
          { role: 'user', content: transcript },
        ],
      }),
    },
  );

  const data = await response.json();
  return data.choices[0].message.content.trim().replace(/^["']|["']$/g, '');
}

async function generateEmbedding(text: string): Promise<number[]> {
  const response = await fetchWithTimeout(
    'https://api.openai.com/v1/embeddings',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'text-embedding-3-small',
        input: text,
      }),
    },
  );

  const data = await response.json();
  return data.data[0].embedding;
}
