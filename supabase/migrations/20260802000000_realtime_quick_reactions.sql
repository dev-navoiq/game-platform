-- quick_reactions was never added to the realtime publication, so emoji
-- reactions were inserted but no client ever received them — the floating
-- bubble pipeline (EmojiBar → quick_reactions → PlayerNode) was dead on
-- arrival (#9). Applied manually to staging 2026-08-02; this migration
-- keeps prod/local in sync.
ALTER PUBLICATION supabase_realtime ADD TABLE quick_reactions;
