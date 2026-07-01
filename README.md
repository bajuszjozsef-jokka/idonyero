# Időnyerő

AI-alapú marketing munkakörnyezet ügyfélprojekt-alapú marketing csapatoknak. A
platform dedikált AI agenteket futtat blokkonként (Meta hirdetésszöveg,
Google Ads, kampánystratégia, kampányoptimalizálás, landing oldal, SEO audit,
blogcikk, versenytárs-elemzés) – projekt kontextusban vagy önálló ("Gyors
blokk") módban.

## Architektúra

```
index.html                     Teljes frontend (HTML + CSS + vanilla JS, egy fájl)
config.example.js              Kliens konfiguráció sablon (Supabase URL/kulcs)
supabase/schema.sql             Adatbázis séma + RLS
supabase/functions/claude-agent Edge Function – Claude API proxy (titkosítja az API kulcsot)
```

A Claude API kulcs **soha nem kerül a böngészőbe**: a frontend a Supabase
Edge Function-t hívja, amely szerveroldalon, environment variable-ként tárolt
kulccsal hívja meg az Anthropic API-t.

A Supabase URL és anon kulcs egy külön, verziókezelésből kizárt `config.js`
fájlból töltődik be (lásd `config.example.js`).

## 1. Supabase projekt létrehozása

1. Hozz létre egy új projektet a [supabase.com](https://supabase.com) oldalon.
2. Az SQL Editorban futtasd le a `supabase/schema.sql` tartalmát – ez létrehozza
   az összes táblát (`clients`, `project_context`, `blocks`, `block_versions`,
   `agent_outputs`, `team_members`), az indexeket és a Row Level Security
   policy-kat.
3. A **Project Settings → API** alatt másold ki a **Project URL**-t és az
   **anon public** kulcsot.

> Az RLS jelenleg engedélyező (`using (true)`) policy-kkal fut, mivel az
> alkalmazás nem tartalmaz felhasználói bejelentkezést (egycsapatos belső
> eszköz). Ha többfelhasználós/Auth-alapú hozzáférés-vezérlésre lesz szükség,
> ezeket a policy-kat kell szigorítani `auth.uid()` alapján.

## 2. Edge Function telepítése (Claude API proxy)

Szükséges a [Supabase CLI](https://supabase.com/docs/guides/cli):

```bash
supabase login
supabase link --project-ref YOUR-PROJECT-REF
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
supabase functions deploy claude-agent --no-verify-jwt
```

A `--no-verify-jwt` kapcsoló azért szükséges, mert a frontend nem küld
Supabase Auth JWT-t (nincs bejelentkezés). Ha később bevezetsz Auth-ot,
távolítsd el ezt a kapcsolót, és a függvény automatikusan megköveteli a JWT-t.

A függvény URL-je (ezt kell majd a `config.js`-be másolni):

```
https://YOUR-PROJECT-REF.supabase.co/functions/v1/claude-agent
```

Az Anthropic API kulcsot a [Anthropic Console](https://console.anthropic.com)
oldalon tudod létrehozni. A proxy kizárólag a `claude-sonnet-4-6` modellt
engedélyezi (költség- és visszaélés-védelem).

## 3. Kliens konfiguráció

```bash
cp config.example.js config.js
```

Töltsd ki a `config.js`-ben:

```js
window.IDONYERO_CONFIG = {
  SUPABASE_URL: "https://YOUR-PROJECT-REF.supabase.co",
  SUPABASE_ANON_KEY: "...",
  CLAUDE_PROXY_URL: "https://YOUR-PROJECT-REF.supabase.co/functions/v1/claude-agent",
};
```

A `config.js` a `.gitignore`-ban szerepel – soha ne commitold, és soha ne
égesd bele a kulcsokat az `index.html`-be.

## 4. Helyi futtatás

Az alkalmazás statikus fájlokból áll, bármilyen statikus szerverrel
futtatható:

```bash
python3 -m http.server 8080
# vagy
npx serve .
```

Nyisd meg: `http://localhost:8080`

## 5. Deploy GitHub Pages-re

1. Pushold a repót GitHub-ra.
2. A repo **Settings → Pages** alatt válaszd a deploy forrást (pl. `main`
   branch, `/ (root)` mappa).
3. **Fontos:** a GitHub Pages build nem futtat build lépést, ezért a
   `config.js` fájlt manuálisan fel kell tölteni a repóba deploy előtt (vagy
   egy külön, nem publikus branch-csel/CI titokkezeléssel kell megoldani,
   mivel az anon kulcs RLS mögött van, de a gyakorlat mégis az, hogy ezt a
   fájlt ne tegyük publikusan elérhetővé verziókezelt formában – helyette pl.
   egy GitHub Actions workflow generálhatja build/deploy időben egy Actions
   secret alapján).

## Blokk típusok

| Blokk | Export | Alkotó agent | Ellenőrző agent(ek) |
|---|---|---|---|
| Meta szövegírás | copy-paste | Meta szövegíró | Korrektor |
| Google Ads szövegek | copy-paste | Google Ads szövegíró | Korrektor |
| Kampánystratégia | docx | Marketing stratéga | Adatelemző ellenőrző |
| Kampányoptimalizálás | docx | Adatelemző | Adatelemző ellenőrző |
| Landing oldal | html | Webdesigner/Frontend fejlesztő | Kód ellenőrző, SEO ellenőrző, Korrektor |
| SEO audit | docx | SEO szakember | Adatelemző ellenőrző |
| Blogcikk | docx | Blogcikk szerző | Korrektor, SEO ellenőrző |
| Versenytárs elemzés | docx | Versenytárs elemző | Adatelemző ellenőrző |

Minden blokk generálásakor a rendszer automatikusan új verziót ment
(`block_versions` tábla), majd lefuttatja a hozzá tartozó ellenőrző
agent(ek)et, és a blokk állapotát "Jóváhagyásra vár" (`reviewing`) státuszba
állítja. A felhasználó jóváhagyása után a státusz `approved`, opcionálisan
`delivered`-re állítható.

## Projekt kontextus gyűjtés (onboarding)

Új ügyfél létrehozásakor a rendszer egy kutató agentet indít, amely a Claude
API **web_search** és **web_fetch** szerveroldali eszközeit használva
feltérképezi az ügyfél publikus digitális lábnyomát (weboldal, sajtó, social
média említések, vélemények), azonosítja a versenytársakat, és strukturált
összefoglalót ment a `project_context` táblába. Csak publikusan elérhető
adatokat dolgoz fel – privát social média tartalmakat, hirdetéskezelői
adatokat a felhasználónak kell manuálisan feltöltenie/megadnia.

## Bővíthetőség

- Új blokk típus hozzáadása: bővítsd a `BLOCK_TYPES` konfigurációs objektumot
  és az `AGENT_PROMPTS` rendszerpromptokat az `index.html`-ben, majd a
  `blocks`/`agent_outputs` táblák `check` constraintjeit a `schema.sql`-ben.
- Új agent típus: vedd fel az `AGENT_PROMPTS`-ba és az `agent_outputs.agent_type`
  check constraintbe.
- Csapatkezelés és határidők: a `team_members` tábla, illetve a `blocks.assigned_to`
  / `blocks.due_date` mezők már elő vannak készítve az adatbázis szintjén,
  de a UI-ban egyelőre nem jelennek meg (a specifikáció szerint).

## Design rendszer

Sötét mód, Inter betűtípus, projektszínek automatikus kiosztással
(`#C17A5A`, `#7A9E9F`, `#9B8BB4`, `#C4A35A`, `#7A9E7A`, `#B47A7A`, `#7A8FA6`,
`#A67A9E`). Lásd az `index.html` `:root` CSS változóit a teljes
színpalettához és tipográfiai skálához.
