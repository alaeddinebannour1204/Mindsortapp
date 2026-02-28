// Supabase Edge Function: process-entry
// Receives a raw speech-to-text transcript, corrects recognition errors,
// formats as clean bullet points, generates a title, picks the best
// existing category (or creates one), and stores the entry.
//
// A DB trigger on `entries` auto-manages category `entry_count`,
// `latest_entry_title`, and `last_updated`. No manual count management here.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const MAX_TRANSCRIPT_LENGTH = 10000;
const OPENAI_TIMEOUT_MS = 25000;
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

/** Fuzzy name match: handles "Health" vs "Health & Fitness", "work" vs "Work", etc. */
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

  return undefined;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
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

    const { transcript, category_id: manualCategoryId, locale } =
      await req.json();
    const lang = typeof locale === 'string' && locale ? locale : 'en';

    if (!transcript || typeof transcript !== 'string') {
      return jsonResponse({ error: 'Missing transcript' }, 400);
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
      .select('id, name, embedding_centroid, entry_count')
      .eq('user_id', user.id)
      .eq('is_archived', false)
      .order('entry_count', { ascending: false });

    const cats = existingCategories ?? [];
    const categoryNames = cats.map((c: { name: string }) => c.name);
    const categoryCount = cats.length;

    const llmResult = await classifyTranscript(
      transcript,
      categoryNames,
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
        match_threshold: 0.55,
      });
      if (sim?.[0]?.similarity >= 0.55) {
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
  existingCategories: string[],
  lang: string = 'en',
): Promise<LLMResult> {
  const categoriesList =
    existingCategories.length > 0
      ? existingCategories.map((c) => `- ${c}`).join('\n')
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
