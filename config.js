// ============================================================================
// Időnyerő – kliens konfiguráció sablon
// ============================================================================
// Másold le ezt a fájlt "config.js" néven (ugyanebbe a mappába, index.html
// mellé) és töltsd ki a saját Supabase projekted adataival.
//
// A config.js fájl .gitignore-olva van: SOHA ne kerüljön verziókezelésbe
// vagy hardcode-olva az index.html-be.
//
// A SUPABASE_ANON_KEY egy publikus, kliensoldali használatra szánt kulcs
// (a védelmet a Row Level Security policy-k adják) – ettől függetlenül nem
// szabad a kódba égetni, mindig ebből a külön fájlból töltődjön be.
//
// A Claude API kulcs SOHA nem kerül ide vagy a böngészőbe: azt a Supabase
// Edge Function (supabase/functions/claude-agent) kezeli szerveroldalon,
// titkosított environment variable-ként.
// ============================================================================

window.IDONYERO_CONFIG = {
  SUPABASE_URL: "https://eabmqumxfglzwukmkqfd.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhYm1xdW14Zmdsend1a21rcWZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5MjkwMjQsImV4cCI6MjA5ODUwNTAyNH0.UvVynHVLv5Rtq9xF49W9R7btDeZ-QID7NgdruSG6DcQ",
  CLAUDE_PROXY_URL: "https://eabmqumxfglzwukmkqfd.supabase.co/functions/v1/claude-agent",
};