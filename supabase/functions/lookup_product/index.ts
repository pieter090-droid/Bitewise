// Supabase Edge Function: lookup_product
//
// Zoekt een product op barcode:
//   1. Supabase `products`-tabel.
//   2. Fallback naar Open Food Facts (alleen hier — nooit client-side).
//   3. Upsert het OFF-product in `products` zodat het gedeeld/gecachet is.
//
// Request : { "barcode": "8710398526007" }
// Response: { "found": true, "source": "...", "product": { ... } }
//       of: { "found": false, "error": "..." }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { barcode } = await req.json();
    if (!barcode || typeof barcode !== "string") {
      return json({ found: false, error: "Ongeldige of ontbrekende barcode." }, 400);
    }
    const code = barcode.trim();
    if (!/^\d{8,14}$/.test(code)) {
      return json({ found: false, error: "Ongeldige barcode." }, 400);
    }

    // Service role: mag schrijven, omzeilt RLS.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 1. Bestaat het al in Supabase?
    const { data: existing } = await supabase
      .from("products")
      .select("*")
      .eq("barcode", code)
      .maybeSingle();

    if (existing) {
      return json({
        found: true,
        source: "supabase",
        product: toClient(existing),
      });
    }

    // 2. Fallback: Open Food Facts.
    const off = await fetchFromOpenFoodFacts(code);
    if (!off) {
      // Een normale miss is geen function-fout: zo kan de Flutter-client hem
      // betrouwbaar van een netwerk-/serverfout onderscheiden.
      return json({ found: false, error: "Geen product gevonden." });
    }

    // 3. Upsert zodat het gedeeld beschikbaar wordt.
    // Live products gebruikt de bestaande, gestandaardiseerde bronwaarde
    // `off`; afwijkende vrije tekst wordt door de database geweigerd.
    const row = { ...off, barcode: code, source: "off" };
    const { data: upserted, error } = await supabase
      .from("products")
      .upsert(row, { onConflict: "barcode" })
      .select("*")
      .single();

    if (error) {
      // Zonder persistente rij bestaan er geen trigger-features en kan de
      // swaplookup het product niet veilig terugvinden. Dus nooit doen alsof
      // een alleen-in-memory OFF-resultaat volledig is toegevoegd.
      console.error("lookup_product upsert failed", error.message);
      return json({
        found: false,
        error: "Product gevonden, maar veilig opslaan is mislukt.",
      }, 500);
    }
    return json({
      found: true,
      source: "open_food_facts_saved",
      product: toClient(upserted),
    });
  } catch (e) {
    return json({ found: false, error: `Interne fout: ${e}` }, 500);
  }
});

// --- Open Food Facts ---
async function fetchFromOpenFoodFacts(barcode: string) {
  const url =
    `https://world.openfoodfacts.org/api/v2/product/${barcode}.json` +
    `?fields=product_name,brands,image_url,categories_tags,nutriments,` +
    `serving_quantity,serving_size,nova_group,nutriscore_grade,` +
    `nutriscore_score,ingredients_text,ingredients_tags,additives_tags,` +
    `additives_n,allergens,completeness,states_tags,main_category,` +
    `pnns_groups_1,pnns_groups_2`;
  const res = await fetch(url, {
    headers: { "User-Agent": "Bitewise/0.1 (support@bitewise.app)" },
  });
  if (!res.ok) return null;
  const data = await res.json();
  if (data.status !== 1 || !data.product) return null;

  const p = data.product;
  const n = p.nutriments ?? {};
  const num = (v: unknown) => {
    if (v === undefined || v === null || v === "") return null;
    const parsed = Number(v);
    return Number.isFinite(parsed) ? parsed : null;
  };

  const categoryTags: string[] = Array.isArray(p.categories_tags)
    ? p.categories_tags
    : [];
  const category = typeof p.main_category === "string"
    ? p.main_category.replace(/^..:/, "")
    : categoryTags.at(-1)?.replace(/^..:/, "") ?? null;

  return {
    name: p.product_name || "Onbekend product",
    brand: (p.brands ?? "").split(",")[0]?.trim() || null,
    image_url: p.image_url ?? null,
    category,
    categories: categoryTags.join(","),
    categories_tags: categoryTags.join(","),
    pnns_groups_1: p.pnns_groups_1 ?? null,
    pnns_groups_2: p.pnns_groups_2 ?? null,
    kcal_100g: num(n["energy-kcal_100g"]),
    protein_100g: num(n["proteins_100g"]),
    sugar_100g: num(n["sugars_100g"]),
    fat_100g: num(n["fat_100g"]),
    saturated_fat_100g: num(n["saturated-fat_100g"]),
    carbs_100g: num(n["carbohydrates_100g"]),
    salt_100g: num(n["salt_100g"]),
    fiber_100g: num(n["fiber_100g"]),
    serving_quantity: num(p.serving_quantity),
    serving_size: p.serving_size ?? null,
    nova_group: num(p.nova_group),
    nutriscore_grade: p.nutriscore_grade ?? null,
    nutriscore_score: num(p.nutriscore_score),
    ingredients_text: p.ingredients_text ?? null,
    ingredients_tags: (p.ingredients_tags ?? []).join(","),
    additives_tags: (p.additives_tags ?? []).join(","),
    additives_n: num(p.additives_n),
    allergens: p.allergens ?? null,
    completeness: num(p.completeness),
    states_tags: (p.states_tags ?? []).join(","),
  };
}

// Zet een DB-rij om naar het client-formaat (geneste nutriments).
function toClient(row: Record<string, unknown>) {
  return {
    barcode: row.barcode,
    name: row.name,
    brand: row.brand,
    image_url: row.image_url,
    category: row.category,
    categories_tags: row.categories_tags,
    kcal_100g: row.kcal_100g,
    protein_100g: row.protein_100g,
    sugar_100g: row.sugar_100g,
    fat_100g: row.fat_100g,
    saturated_fat_100g: row.saturated_fat_100g,
    carbs_100g: row.carbs_100g,
    salt_100g: row.salt_100g,
    fiber_100g: row.fiber_100g,
    serving_quantity: row.serving_quantity,
    serving_size: row.serving_size,
    nova_group: row.nova_group,
    nutriscore_grade: row.nutriscore_grade,
  };
}
