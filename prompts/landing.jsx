import { useState, useEffect, useRef, useCallback, createContext, useContext } from "react";

// ─── Theme Definitions ───

const THEMES = {
  crystal: {
    id: "crystal",
    label: "Refined Crystal",
    icon: "🌿",
    feltDark: "#122e1d",
    feltMid: "#1d4a2e",
    feltLight: "#2a6641",
    accent: "#C47B2B",
    accentSoft: "#E8A84F",
    accentGlow: "rgba(196,123,43,0.22)",
    glass: "rgba(255,255,255,0.52)",
    glassBorder: "rgba(255,255,255,0.72)",
    glassDark: "rgba(255,255,255,0.06)",
    glassDarkBorder: "rgba(255,255,255,0.12)",
    glassModalBg: "rgba(255,255,255,0.52)",
    textDark: "#241810",
    textMuted: "#9c7d62",
    textOnFelt: "rgba(255,255,255,0.92)",
    textFeltMuted: "rgba(255,255,255,0.48)",
    success: "#27ae60",
    danger: "#e74c3c",
    cardRed: "#c0392b",
    cardBlack: "#1a1a2a",
    avatarGradient: "linear-gradient(135deg, #f0e8da, #e5d4bc)",
    tileBg: "rgba(255,255,255,0.06)",
    tileHoverBg: "rgba(255,255,255,0.08)",
    tileActiveBg: "rgba(196,123,43,0.08)",
    rowHoverBg: "rgba(255,255,255,0.06)",
    rowBg: "rgba(255,255,255,0.015)",
    inputBg: "rgba(0,0,0,0.04)",
    inputBorder: "rgba(0,0,0,0.08)",
    overlayBg: "rgba(0,0,0,0.5)",
    navGradient: "linear-gradient(to top, #122e1d 60%, transparent)",
    btnTextColor: "#fff",
    bgGradient: `
      radial-gradient(ellipse at 15% 0%, #2a664144 0%, transparent 45%),
      radial-gradient(ellipse at 85% 100%, #2a664128 0%, transparent 45%),
      radial-gradient(ellipse at 50% 50%, #1d4a2e 0%, #122e1d 100%)
    `,
    decorCardBg: "#fff",
    decorCardOpacity: 0.10,
    feltTextureOpacity: 0.012,
    borderWidth: 1,
    fontScale: 1,
    minTouch: 0,
  },

  obsidian: {
    id: "obsidian",
    label: "Dark Obsidian",
    icon: "🌑",
    feltDark: "#0a0a0f",
    feltMid: "#111118",
    feltLight: "#1a1a26",
    accent: "#8b9dc3",
    accentSoft: "#aec0de",
    accentGlow: "rgba(139,157,195,0.18)",
    glass: "rgba(255,255,255,0.06)",
    glassBorder: "rgba(255,255,255,0.10)",
    glassDark: "rgba(255,255,255,0.04)",
    glassDarkBorder: "rgba(255,255,255,0.08)",
    glassModalBg: "rgba(20,20,30,0.92)",
    textDark: "#e8e8ec",
    textMuted: "#6b7084",
    textOnFelt: "rgba(255,255,255,0.88)",
    textFeltMuted: "rgba(255,255,255,0.38)",
    success: "#2ecc71",
    danger: "#e74c3c",
    cardRed: "#e06050",
    cardBlack: "#555566",
    avatarGradient: "linear-gradient(135deg, #2a2a38, #1e1e2a)",
    tileBg: "rgba(255,255,255,0.04)",
    tileHoverBg: "rgba(255,255,255,0.07)",
    tileActiveBg: "rgba(139,157,195,0.10)",
    rowHoverBg: "rgba(255,255,255,0.05)",
    rowBg: "rgba(255,255,255,0.01)",
    inputBg: "rgba(255,255,255,0.06)",
    inputBorder: "rgba(255,255,255,0.10)",
    overlayBg: "rgba(0,0,0,0.7)",
    navGradient: "linear-gradient(to top, #0a0a0f 60%, transparent)",
    btnTextColor: "#fff",
    bgGradient: `
      radial-gradient(ellipse at 20% 0%, #1a1a2655 0%, transparent 45%),
      radial-gradient(ellipse at 80% 100%, #1a1028 0%, transparent 45%),
      radial-gradient(ellipse at 50% 50%, #111118 0%, #0a0a0f 100%)
    `,
    decorCardBg: "#1a1a26",
    decorCardOpacity: 0.05,
    feltTextureOpacity: 0.008,
    borderWidth: 1,
    fontScale: 1,
    minTouch: 0,
  },

  highContrast: {
    id: "highContrast",
    label: "High Contrast",
    icon: "👁️",
    feltDark: "#000000",
    feltMid: "#0a0a0a",
    feltLight: "#1a1a1a",
    accent: "#FFD700",
    accentSoft: "#FFE44D",
    accentGlow: "rgba(255,215,0,0.25)",
    glass: "rgba(255,255,255,0.10)",
    glassBorder: "rgba(255,255,255,0.50)",
    glassDark: "rgba(255,255,255,0.08)",
    glassDarkBorder: "rgba(255,255,255,0.35)",
    glassModalBg: "rgba(0,0,0,0.95)",
    textDark: "#FFFFFF",
    textMuted: "#cccccc",
    textOnFelt: "#FFFFFF",
    textFeltMuted: "rgba(255,255,255,0.70)",
    success: "#00FF88",
    danger: "#FF4444",
    cardRed: "#FF4444",
    cardBlack: "#BBBBBB",
    avatarGradient: "linear-gradient(135deg, #333333, #222222)",
    tileBg: "rgba(255,255,255,0.08)",
    tileHoverBg: "rgba(255,255,255,0.14)",
    tileActiveBg: "rgba(255,215,0,0.14)",
    rowHoverBg: "rgba(255,255,255,0.10)",
    rowBg: "rgba(255,255,255,0.03)",
    inputBg: "rgba(255,255,255,0.10)",
    inputBorder: "rgba(255,255,255,0.40)",
    overlayBg: "rgba(0,0,0,0.8)",
    navGradient: "linear-gradient(to top, #000000 60%, transparent)",
    btnTextColor: "#000",
    bgGradient: "linear-gradient(180deg, #0a0a0a 0%, #000000 100%)",
    decorCardBg: "#111111",
    decorCardOpacity: 0.06,
    feltTextureOpacity: 0,
    borderWidth: 2,
    fontScale: 1.1,
    minTouch: 44,
  },
};

const ThemeContext = createContext(THEMES.crystal);
const useTheme = () => useContext(ThemeContext);

// ─── Game Data ───
const CARD_GAMES = [
  { id: "twentynine", name: "Twenty-Nine", emoji: "🃏", players: "4", online: 342, hot: true, desc: "Classic South Asian trick-taking game with bidding." },
  { id: "ohhell", name: "Oh Hell", emoji: "🔥", players: "3–7", online: 128, desc: "Predict your tricks exactly — no more, no less." },
  { id: "bridge", name: "Bridge", emoji: "♠️", players: "4", online: 89, desc: "The king of partnership card games." },
  { id: "hearts", name: "Hearts", emoji: "♥️", players: "4", online: 276, hot: true, desc: "Avoid hearts and the dreaded Queen of Spades." },
  { id: "spades", name: "Spades", emoji: "♣️", players: "4", online: 195, desc: "Bid and win tricks with your partner." },
  { id: "rummy", name: "Rummy", emoji: "🎴", players: "2–6", online: 410, hot: true, desc: "Form sets and runs to go out first." },
];

const BOARD_GAMES = [
  { id: "chess", name: "Chess", emoji: "♟️", players: "2", online: 1204, hot: true, desc: "The timeless game of strategy and foresight." },
  { id: "ludo", name: "Ludo", emoji: "🎲", players: "2–4", online: 567, desc: "Race your tokens home before your opponents." },
  { id: "sequence", name: "Sequence", emoji: "🔢", players: "2–3 teams", online: 143, hot: true, desc: "Play cards to form sequences on the board." },
];

const ROOMS_BY_GAME = {
  twentynine: [
    { host: "Arjun", players: "3/4", level: "Casual", avatar: "🧔" },
    { host: "Priya", players: "2/4", level: "Ranked", avatar: "👩" },
    { host: "Dev", players: "3/4", level: "Casual", avatar: "🧑" },
  ],
  hearts: [
    { host: "Sam", players: "2/4", level: "Casual", avatar: "😎" },
    { host: "Luna", players: "3/4", level: "Ranked", avatar: "🌙" },
  ],
  chess: [
    { host: "Maya", players: "1/2", level: "Ranked", avatar: "👸" },
    { host: "Kai", players: "1/2", level: "Casual", avatar: "🧙" },
    { host: "Zara", players: "1/2", level: "Ranked", avatar: "🦊" },
  ],
  rummy: [
    { host: "Rahul", players: "3/6", level: "Casual", avatar: "🎯" },
    { host: "Anya", players: "2/4", level: "Casual", avatar: "🌸" },
  ],
  ohhell: [{ host: "Finn", players: "4/6", level: "Casual", avatar: "🐳" }],
  bridge: [{ host: "Eleanor", players: "2/4", level: "Ranked", avatar: "👑" }],
  spades: [{ host: "Tyrone", players: "3/4", level: "Ranked", avatar: "⚡" }],
  ludo: [
    { host: "Neha", players: "2/4", level: "Casual", avatar: "🎀" },
    { host: "Omar", players: "3/4", level: "Casual", avatar: "🚀" },
  ],
  sequence: [{ host: "Chloe", players: "1/2", level: "Casual", avatar: "🌈" }],
};

const TOURNAMENTS_BY_GAME = {
  twentynine: [
    { type: "Double Elimination", players: "12/16", prize: "500 🪙", startsIn: "2h 15m" },
    { type: "Round Robin", players: "6/8", prize: "200 🪙", startsIn: "5h" },
  ],
  hearts: [{ type: "Round Robin", players: "8/8", prize: "250 🪙", startsIn: "Live" }],
  chess: [
    { type: "Swiss Round", players: "28/32", prize: "1,000 🪙", startsIn: "45m" },
    { type: "Single Elimination", players: "14/16", prize: "750 🪙", startsIn: "3h" },
  ],
  rummy: [{ type: "Single Elimination", players: "10/16", prize: "400 🪙", startsIn: "1h 30m" }],
  ludo: [{ type: "Single Elimination", players: "6/8", prize: "300 🪙", startsIn: "4h 30m" }],
  sequence: [{ type: "Round Robin", players: "4/6", prize: "350 🪙", startsIn: "6h" }],
};

// ─── Themed helpers ───
function useFontSize(base) {
  const t = useTheme();
  return Math.round(base * t.fontScale);
}

// ─── Reusable Components ───

function GlassPanel({ children, style, radius = 20, dark = false, onClick, hoverGlow }) {
  const t = useTheme();
  const [hov, setHov] = useState(false);
  const bg = dark ? t.glassDark : t.glass;
  const border = dark
    ? (hov && hoverGlow ? hoverGlow + "44" : t.glassDarkBorder)
    : t.glassBorder;

  return (
    <div onClick={onClick} onMouseEnter={() => setHov(true)} onMouseLeave={() => setHov(false)}
      style={{
        background: bg,
        border: `${t.borderWidth}px solid ${border}`,
        backdropFilter: "blur(18px) saturate(1.35)",
        WebkitBackdropFilter: "blur(18px) saturate(1.35)",
        borderRadius: radius,
        boxShadow: dark
          ? hov && hoverGlow
            ? `0 8px 32px ${hoverGlow}18, 0 0 0 1px ${hoverGlow}22`
            : "0 4px 24px rgba(0,0,0,0.18)"
          : "0 4px 20px rgba(60,40,20,0.10), inset 0 1px 3px rgba(255,255,255,0.25)",
        cursor: onClick ? "pointer" : "default",
        transition: "all 0.3s cubic-bezier(0.34,1.56,0.64,1)",
        transform: onClick && hov ? "translateY(-2px)" : "none",
        ...style,
      }}
    >{children}</div>
  );
}

function AccentButton({ children, style, onClick, secondary, small }) {
  const t = useTheme();
  const sz = useFontSize(small ? 11 : 13);
  const [h, setH] = useState(false);
  return (
    <button onClick={onClick} onMouseEnter={() => setH(true)} onMouseLeave={() => setH(false)}
      style={{
        background: secondary ? "transparent"
          : h ? `linear-gradient(135deg, ${t.accentSoft}, ${t.accent})`
          : `linear-gradient(135deg, ${t.accent}, ${t.id === "highContrast" ? "#b8960a" : t.id === "obsidian" ? "#6880a8" : "#a5621f"})`,
        border: secondary ? `${Math.max(t.borderWidth, 1.5)}px solid ${h ? t.accent : t.accent + "88"}` : "none",
        borderRadius: small ? 10 : 13,
        padding: small ? "6px 14px" : "10px 22px",
        color: secondary ? (h ? t.accentSoft : t.accent) : t.btnTextColor,
        fontFamily: "'DM Sans', sans-serif",
        fontWeight: t.id === "highContrast" ? 700 : 600,
        fontSize: sz,
        cursor: "pointer",
        display: "inline-flex", alignItems: "center", gap: 7,
        transition: "all 0.25s ease",
        transform: h ? "translateY(-1px)" : "none",
        boxShadow: h && !secondary ? `0 8px 28px ${t.accentGlow}` : secondary ? "none" : `0 4px 16px ${t.accentGlow}`,
        whiteSpace: "nowrap",
        minHeight: t.minTouch || undefined,
        ...style,
      }}
    >{children}</button>
  );
}

// ─── Theme Switcher ───
function ThemeSwitcher({ current, onChange }) {
  const t = useTheme();
  const [open, setOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    if (!open) return;
    const handler = (e) => { if (ref.current && !ref.current.contains(e.target)) setOpen(false); };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [open]);

  return (
    <div ref={ref} style={{ position: "relative" }}>
      <div onClick={() => setOpen(!open)}
        style={{
          width: 36, height: 36, borderRadius: 10,
          background: t.glassDark, border: `${t.borderWidth}px solid ${t.glassDarkBorder}`,
          display: "flex", alignItems: "center", justifyContent: "center",
          cursor: "pointer", fontSize: 16, backdropFilter: "blur(18px)",
          transition: "all 0.2s ease",
        }}>🎨</div>

      {open && (
        <div style={{
          position: "absolute", top: 42, right: 0, zIndex: 50,
          animation: "fadeInUp 0.25s cubic-bezier(0.34,1.56,0.64,1)",
        }}>
          <GlassPanel dark radius={16} style={{ padding: "8px 6px", minWidth: 195 }}>
            {Object.values(THEMES).map((theme) => (
              <div key={theme.id}
                onClick={() => { onChange(theme.id); setOpen(false); }}
                style={{
                  display: "flex", alignItems: "center", gap: 10,
                  padding: "9px 12px", borderRadius: 10,
                  background: current === theme.id ? `${t.accent}18` : "transparent",
                  border: `${t.borderWidth}px solid ${current === theme.id ? t.accent + "44" : "transparent"}`,
                  cursor: "pointer", transition: "all 0.2s ease",
                }}>
                <span style={{ fontSize: 18 }}>{theme.icon}</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: useFontSize(12), fontWeight: 600, color: t.textOnFelt }}>{theme.label}</div>
                  <div style={{ fontSize: useFontSize(9), color: t.textFeltMuted }}>
                    {theme.id === "crystal" && "Warm felt green, gold accents"}
                    {theme.id === "obsidian" && "True dark, silver & cool tones"}
                    {theme.id === "highContrast" && "Bold borders, max readability"}
                  </div>
                </div>
                {current === theme.id && (
                  <span style={{ color: t.accent, fontSize: 14, fontWeight: 700 }}>✓</span>
                )}
              </div>
            ))}
          </GlassPanel>
        </div>
      )}
    </div>
  );
}

// ─── Game Tile ───
function GameTile({ game, selected, onSelect, delay }) {
  const t = useTheme();
  const [visible, setVisible] = useState(false);
  const [hov, setHov] = useState(false);
  const isActive = selected === game.id;

  useEffect(() => {
    const tm = setTimeout(() => setVisible(true), delay);
    return () => clearTimeout(tm);
  }, [delay]);

  return (
    <div onClick={() => onSelect(isActive ? null : game.id)}
      onMouseEnter={() => setHov(true)} onMouseLeave={() => setHov(false)}
      style={{
        opacity: visible ? 1 : 0,
        transform: visible ? (hov && !isActive ? "translateY(-4px)" : "translateY(0)") : "translateY(20px)",
        transition: "all 0.4s cubic-bezier(0.34,1.56,0.64,1)",
        cursor: "pointer", position: "relative", flex: "0 0 auto",
      }}>
      <div style={{
        padding: "16px 18px 14px", minWidth: 108, textAlign: "center",
        borderRadius: 16,
        background: isActive ? t.tileActiveBg : hov ? t.tileHoverBg : t.tileBg,
        border: `${t.borderWidth}px solid ${isActive ? t.accent + "55" : hov ? "rgba(255,255,255,0.14)" : t.glassDarkBorder}`,
        backdropFilter: "blur(18px) saturate(1.35)",
        boxShadow: isActive
          ? `0 8px 32px ${t.accentGlow}, 0 0 0 1px ${t.accent}33`
          : hov ? "0 8px 28px rgba(0,0,0,0.22)" : "0 4px 24px rgba(0,0,0,0.18)",
        transition: "all 0.3s cubic-bezier(0.34,1.56,0.64,1)",
        position: "relative", minHeight: t.minTouch || undefined,
        display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
      }}>
        {game.hot && (
          <div style={{
            position: "absolute", top: -5, right: -5,
            background: `linear-gradient(135deg, ${t.danger}, ${t.id === "highContrast" ? "#cc0000" : "#c0392b"})`,
            borderRadius: 100, padding: "2px 7px",
            fontSize: useFontSize(8), fontWeight: 700, color: "#fff",
            fontFamily: "'DM Sans', sans-serif", letterSpacing: 0.5,
            boxShadow: `0 2px 8px ${t.danger}55`,
            border: t.id === "highContrast" ? "1px solid #fff" : "none",
          }}>HOT</div>
        )}
        <div style={{ fontSize: 30, marginBottom: 6, filter: isActive || hov ? "none" : "saturate(0.75)", transition: "filter 0.3s" }}>{game.emoji}</div>
        <div style={{ fontFamily: "'DM Serif Display', serif", fontSize: useFontSize(13), color: t.textOnFelt, marginBottom: 3 }}>{game.name}</div>
        <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: useFontSize(9), color: t.textFeltMuted, display: "flex", alignItems: "center", justifyContent: "center", gap: 4 }}>
          {game.players}P
          <span style={{ width: 3, height: 3, borderRadius: "50%", background: t.success, display: "inline-block", boxShadow: `0 0 4px ${t.success}` }} />
          {game.online}
        </div>
        {isActive && (
          <div style={{
            position: "absolute", bottom: -8, left: "50%", transform: "translateX(-50%)",
            width: 0, height: 0,
            borderLeft: "7px solid transparent", borderRight: "7px solid transparent",
            borderTop: `7px solid ${t.accent}55`,
            filter: `drop-shadow(0 2px 4px ${t.accentGlow})`,
          }} />
        )}
      </div>
    </div>
  );
}

// ─── Expanded Detail Panel ───
function GameDetailPanel({ game, rooms, tournaments }) {
  const t = useTheme();
  const [visible, setVisible] = useState(false);
  const panelRef = useRef(null);

  useEffect(() => {
    setVisible(false);
    const tm = setTimeout(() => setVisible(true), 30);
    return () => clearTimeout(tm);
  }, [game.id]);

  useEffect(() => {
    if (panelRef.current) panelRef.current.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }, [game.id]);

  const hasRooms = rooms?.length > 0;
  const hasTournaments = tournaments?.length > 0;

  return (
    <div ref={panelRef} style={{
      opacity: visible ? 1 : 0, maxHeight: visible ? 650 : 0,
      transform: visible ? "translateY(0) scale(1)" : "translateY(8px) scale(0.99)",
      transition: "all 0.45s cubic-bezier(0.34,1.56,0.64,1)",
      marginTop: 12, marginBottom: 6, overflow: "hidden",
    }}>
      <GlassPanel dark radius={20} style={{ padding: "20px 18px", border: `${t.borderWidth}px solid ${t.accent}22` }}>
        {/* Header */}
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 18, flexWrap: "wrap", gap: 12 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
            <div style={{ width: 50, height: 50, borderRadius: 14, background: `${t.accent}15`, border: `${t.borderWidth}px solid ${t.accent}30`, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 26 }}>{game.emoji}</div>
            <div>
              <div style={{ fontFamily: "'DM Serif Display', serif", fontSize: useFontSize(19), color: t.textOnFelt, lineHeight: 1.2 }}>{game.name}</div>
              <div style={{ fontSize: useFontSize(11), color: t.textFeltMuted, marginTop: 2, maxWidth: 260, lineHeight: 1.4 }}>{game.desc}</div>
            </div>
          </div>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
            <AccentButton small><span style={{ fontSize: 13 }}>⚡</span> Quick Match</AccentButton>
            <AccentButton small secondary><span style={{ fontSize: 12 }}>＋</span> Create Room</AccentButton>
          </div>
        </div>

        {/* Columns */}
        <div style={{ display: "flex", gap: 14, flexWrap: "wrap" }}>
          <div style={{ flex: "1 1 260px", minWidth: 0 }}>
            <ColHeader icon="🚪" label="Open Rooms" count={hasRooms ? rooms.length : 0} />
            {hasRooms
              ? <div style={{ display: "flex", flexDirection: "column", gap: 3 }}>{rooms.map((r, i) => <RoomRow key={i} room={r} index={i} />)}</div>
              : <EmptySlot text="No open rooms right now" action="Be the first" />}
          </div>
          <div style={{ flex: "1 1 260px", minWidth: 0 }}>
            <ColHeader icon="🏆" label="Tournaments" count={hasTournaments ? tournaments.length : 0} />
            {hasTournaments
              ? <div style={{ display: "flex", flexDirection: "column", gap: 5 }}>{tournaments.map((tt, i) => <TourneyRow key={i} data={tt} index={i} />)}</div>
              : <EmptySlot text="No tournaments scheduled" />}
          </div>
        </div>
      </GlassPanel>
    </div>
  );
}

function ColHeader({ icon, label, count }) {
  const t = useTheme();
  return (
    <div style={{ fontSize: useFontSize(10), fontWeight: 700, color: t.textFeltMuted, textTransform: "uppercase", letterSpacing: 1.2, marginBottom: 8, display: "flex", alignItems: "center", gap: 6 }}>
      <span style={{ fontSize: useFontSize(11) }}>{icon}</span> {label}
      {count > 0 && <span style={{ background: t.accent + "33", color: t.accentSoft, borderRadius: 100, padding: "1px 7px", fontSize: useFontSize(9), fontWeight: 700, letterSpacing: 0, textTransform: "none" }}>{count}</span>}
    </div>
  );
}

function EmptySlot({ text, action }) {
  const t = useTheme();
  return (
    <div style={{ padding: "18px 14px", textAlign: "center", borderRadius: 12, background: "rgba(255,255,255,0.02)", border: `${t.borderWidth}px dashed ${t.glassDarkBorder}` }}>
      <div style={{ fontSize: useFontSize(10), color: t.textFeltMuted, marginBottom: action ? 8 : 0 }}>{text}</div>
      {action && <AccentButton small><span style={{ fontSize: 11 }}>＋</span> {action}</AccentButton>}
    </div>
  );
}

function RoomRow({ room, index }) {
  const t = useTheme();
  const [h, setH] = useState(false);
  const [vis, setVis] = useState(false);
  useEffect(() => { const tm = setTimeout(() => setVis(true), 50 + index * 45); return () => clearTimeout(tm); }, [index]);

  return (
    <div onMouseEnter={() => setH(true)} onMouseLeave={() => setH(false)}
      style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "7px 10px", borderRadius: 11,
        background: h ? t.rowHoverBg : t.rowBg,
        border: `${t.borderWidth}px solid ${h ? "rgba(255,255,255,0.09)" : "transparent"}`,
        transition: "all 0.2s ease", cursor: "pointer",
        opacity: vis ? 1 : 0, transform: vis ? "none" : "translateX(-8px)",
        minHeight: t.minTouch || undefined,
      }}>
      <div style={{ display: "flex", alignItems: "center", gap: 9 }}>
        <div style={{ width: 30, height: 30, borderRadius: 9, background: t.avatarGradient, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 15 }}>{room.avatar}</div>
        <div>
          <div style={{ fontSize: useFontSize(11), fontWeight: 600, color: t.textOnFelt }}>{room.host}</div>
          <div style={{ fontSize: useFontSize(9), color: t.textFeltMuted }}>
            {room.players} · <span style={{ color: room.level === "Ranked" ? t.accentSoft : t.textFeltMuted, fontWeight: room.level === "Ranked" ? 700 : 500 }}>{room.level}</span>
          </div>
        </div>
      </div>
      <AccentButton small style={{ padding: "4px 12px", fontSize: useFontSize(10), borderRadius: 8 }}>Join</AccentButton>
    </div>
  );
}

function TourneyRow({ data, index }) {
  const t = useTheme();
  const [h, setH] = useState(false);
  const [vis, setVis] = useState(false);
  const isLive = data.startsIn === "Live";
  useEffect(() => { const tm = setTimeout(() => setVis(true), 60 + index * 50); return () => clearTimeout(tm); }, [index]);

  const fillPct = (() => { const p = data.players.split("/"); return (parseInt(p[0]) / parseInt(p[1])) * 100; })();

  return (
    <div onMouseEnter={() => setH(true)} onMouseLeave={() => setH(false)}
      style={{
        padding: "9px 12px", borderRadius: 11,
        background: h ? t.rowHoverBg : t.rowBg,
        border: `${t.borderWidth}px solid ${h ? "rgba(255,255,255,0.09)" : "transparent"}`,
        transition: "all 0.2s ease", cursor: "pointer",
        opacity: vis ? 1 : 0, transform: vis ? "none" : "translateX(-8px)",
        minHeight: t.minTouch || undefined,
      }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 5 }}>
        <div style={{ fontSize: useFontSize(11), fontWeight: 600, color: t.textOnFelt }}>{data.type}</div>
        <span style={{
          background: isLive ? `${t.danger}22` : `${t.accent}18`,
          color: isLive ? t.danger : t.accentSoft,
          borderRadius: 100, padding: "2px 8px",
          fontSize: useFontSize(9), fontWeight: 700,
          display: "flex", alignItems: "center", gap: 4,
          border: t.id === "highContrast" ? `1px solid ${isLive ? t.danger : t.accent}` : "none",
        }}>
          {isLive && <span style={{ width: 5, height: 5, borderRadius: "50%", background: t.danger, animation: "livePulse 1.2s ease-in-out infinite" }} />}
          {isLive ? "LIVE" : data.startsIn}
        </span>
      </div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 5 }}>
          <span style={{ fontSize: useFontSize(9), color: t.textFeltMuted }}>{data.players}</span>
          <div style={{ width: 46, height: t.id === "highContrast" ? 5 : 3, borderRadius: 2, background: "rgba(255,255,255,0.06)", overflow: "hidden", border: t.id === "highContrast" ? "1px solid rgba(255,255,255,0.2)" : "none" }}>
            <div style={{ width: `${fillPct}%`, height: "100%", borderRadius: 2, background: isLive ? `linear-gradient(90deg, ${t.danger}, ${t.danger}88)` : `linear-gradient(90deg, ${t.accent}, ${t.accentSoft})` }} />
          </div>
        </div>
        <span style={{ fontFamily: "'DM Serif Display', serif", fontSize: useFontSize(11), color: t.accentSoft }}>{data.prize}</span>
      </div>
    </div>
  );
}

// ─── Decorative ───
function FloatingCard({ suit, rank, style: s, delay }) {
  const t = useTheme();
  const [v, setV] = useState(false);
  useEffect(() => { const tm = setTimeout(() => setV(true), delay); return () => clearTimeout(tm); }, [delay]);
  const isRed = suit === "♥" || suit === "♦";
  return (
    <div style={{
      position: "absolute", width: 42, height: 60, borderRadius: 6,
      background: t.decorCardBg, border: `1px solid ${t.glassDarkBorder}`,
      boxShadow: "0 8px 32px rgba(0,0,0,0.1)",
      display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
      fontFamily: "'DM Serif Display', serif",
      color: isRed ? t.cardRed : t.cardBlack,
      pointerEvents: "none", opacity: v ? t.decorCardOpacity : 0,
      transform: v ? "none" : "scale(0.7)",
      transition: "all 0.8s cubic-bezier(0.34,1.56,0.64,1)", zIndex: 0, ...s,
    }}>
      <div style={{ fontSize: 13, lineHeight: 1 }}>{rank}</div>
      <div style={{ fontSize: 11 }}>{suit}</div>
    </div>
  );
}

function SectionLabel({ children, icon }) {
  const t = useTheme();
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 14 }}>
      {icon && <span style={{ fontSize: 17 }}>{icon}</span>}
      <h2 style={{ fontFamily: "'DM Serif Display', serif", fontSize: useFontSize(19), fontWeight: 400, color: t.textOnFelt, margin: 0 }}>{children}</h2>
    </div>
  );
}

function GlobalTournamentCard({ data, index }) {
  const t = useTheme();
  const [v, setV] = useState(false);
  const isLive = data.startsIn === "Live";
  useEffect(() => { const tm = setTimeout(() => setV(true), 400 + index * 90); return () => clearTimeout(tm); }, [index]);
  const fillPct = (() => { const p = data.players.split("/"); return (parseInt(p[0]) / parseInt(p[1])) * 100; })();

  return (
    <div style={{
      opacity: v ? 1 : 0, transform: v ? "none" : "translateY(16px)",
      transition: "all 0.4s cubic-bezier(0.34,1.56,0.64,1)",
      flex: "0 0 210px", cursor: "pointer",
    }}>
      <GlassPanel dark radius={16} hoverGlow={data.color} onClick={() => {}} style={{ padding: "14px 15px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8 }}>
          <span style={{ fontSize: 19 }}>{data.emoji}</span>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: "'DM Serif Display', serif", fontSize: useFontSize(13), color: t.textOnFelt, lineHeight: 1.2 }}>{data.game}</div>
            <div style={{ fontSize: useFontSize(9), color: t.textFeltMuted }}>{data.type}</div>
          </div>
          <span style={{
            background: isLive ? `${t.danger}22` : `${data.color}18`,
            color: isLive ? t.danger : data.color,
            borderRadius: 100, padding: "2px 7px", fontSize: useFontSize(8), fontWeight: 700,
            display: "flex", alignItems: "center", gap: 3, flexShrink: 0,
            border: t.id === "highContrast" ? `1px solid ${isLive ? t.danger : data.color}` : "none",
          }}>
            {isLive && <span style={{ width: 4, height: 4, borderRadius: "50%", background: t.danger, animation: "livePulse 1.2s ease-in-out infinite" }} />}
            {isLive ? "LIVE" : data.startsIn}
          </span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 5 }}>
            <span style={{ fontSize: useFontSize(9), color: t.textFeltMuted }}>{data.players}</span>
            <div style={{ width: 44, height: t.id === "highContrast" ? 5 : 3, borderRadius: 2, background: "rgba(255,255,255,0.06)", overflow: "hidden" }}>
              <div style={{ width: `${fillPct}%`, height: "100%", borderRadius: 2, background: isLive ? `linear-gradient(90deg, ${t.danger}, ${t.danger}88)` : `linear-gradient(90deg, ${data.color}, ${data.color}88)` }} />
            </div>
          </div>
          <span style={{ fontFamily: "'DM Serif Display', serif", fontSize: useFontSize(11), color: t.accentSoft }}>{data.prize}</span>
        </div>
      </GlassPanel>
    </div>
  );
}

// ═══════════════════════════════════════════════
// MAIN APP
// ═══════════════════════════════════════════════
export default function GameLandingScreen() {
  const [themeId, setThemeId] = useState("crystal");
  const [selectedGame, setSelectedGame] = useState(null);
  const [joinCodeOpen, setJoinCodeOpen] = useState(false);
  const [joinCode, setJoinCode] = useState("");

  const theme = THEMES[themeId];

  const handleSelect = useCallback((id) => {
    setSelectedGame((prev) => (prev === id ? null : id));
  }, []);

  const renderSection = (games, label, icon, baseDelay) => (
    <div style={{ marginBottom: selectedGame && games.find(g => g.id === selectedGame) ? 8 : 28 }}>
      <SectionLabel icon={icon}>{label}</SectionLabel>
      <div className="scroll-h" style={{ display: "flex", gap: 10, overflowX: "auto", paddingBottom: 10, WebkitOverflowScrolling: "touch" }}>
        {games.map((g, i) => <GameTile key={g.id} game={g} selected={selectedGame} onSelect={handleSelect} delay={baseDelay + i * 60} />)}
      </div>
      {selectedGame && games.find(g => g.id === selectedGame) && (
        <GameDetailPanel
          game={games.find(g => g.id === selectedGame)}
          rooms={ROOMS_BY_GAME[selectedGame] || []}
          tournaments={TOURNAMENTS_BY_GAME[selectedGame] || []}
        />
      )}
    </div>
  );

  const globalTourneys = [
    { game: "Chess", emoji: "♟️", type: "Swiss Round", players: "28/32", prize: "1,000 🪙", startsIn: "45m", color: theme.success },
    { game: "Hearts", emoji: "♥️", type: "Round Robin", players: "8/8", prize: "250 🪙", startsIn: "Live", color: theme.danger },
    { game: "Twenty-Nine", emoji: "🃏", type: "Double Elim", players: "12/16", prize: "500 🪙", startsIn: "2h 15m", color: theme.accent },
    { game: "Rummy", emoji: "🎴", type: "Single Elim", players: "10/16", prize: "400 🪙", startsIn: "1h 30m", color: theme.accentSoft },
  ];

  return (
    <ThemeContext.Provider value={theme}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;0,9..40,700&family=DM+Serif+Display&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { overflow-x: hidden; }
        @keyframes livePulse { 0%,100%{opacity:1;transform:scale(1)} 50%{opacity:0.4;transform:scale(0.65)} }
        @keyframes fadeInUp { from{opacity:0;transform:translateY(24px)} to{opacity:1;transform:translateY(0)} }
        .scroll-h { scrollbar-width:none; -ms-overflow-style:none; }
        .scroll-h::-webkit-scrollbar { display:none; }
      `}</style>

      <div style={{
        minHeight: "100vh", background: theme.bgGradient,
        fontFamily: "'DM Sans', sans-serif",
        position: "relative", overflow: "hidden",
        transition: "background 0.6s ease",
      }}>
        {/* Texture */}
        {theme.feltTextureOpacity > 0 && (
          <div style={{
            position: "fixed", inset: 0, pointerEvents: "none", zIndex: 0,
            backgroundImage: `url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23ffffff' fill-opacity='${theme.feltTextureOpacity}'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")`,
          }} />
        )}

        {/* Floating cards */}
        <FloatingCard suit="♠" rank="A" style={{ top: 140, left: "4%", transform: "rotate(-15deg)" }} delay={300} />
        <FloatingCard suit="♥" rank="K" style={{ top: 320, right: "6%", transform: "rotate(12deg)" }} delay={500} />
        <FloatingCard suit="♦" rank="Q" style={{ bottom: 340, left: "2%", transform: "rotate(8deg)" }} delay={700} />
        <FloatingCard suit="♣" rank="J" style={{ bottom: 120, right: "3%", transform: "rotate(-10deg)" }} delay={900} />

        <div style={{ position: "relative", zIndex: 1, maxWidth: 860, margin: "0 auto", padding: "0 20px" }}>

          {/* ─── Header ─── */}
          <header style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "18px 0", animation: "fadeInUp 0.5s ease-out" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 11 }}>
              <div style={{
                width: 38, height: 38, borderRadius: 11,
                background: `linear-gradient(135deg, ${theme.accent}, ${theme.accentSoft})`,
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 19, boxShadow: `0 4px 14px ${theme.accentGlow}`,
                color: theme.btnTextColor,
              }}>♠</div>
              <div>
                <div style={{ fontFamily: "'DM Serif Display', serif", fontSize: useFontSize(18), color: theme.textOnFelt, lineHeight: 1.1 }}>GameTable</div>
                <div style={{ fontSize: useFontSize(9), color: theme.textFeltMuted, letterSpacing: 1.5, textTransform: "uppercase" }}>Premium Play</div>
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
              <GlassPanel dark radius={100} onClick={() => setJoinCodeOpen(true)}
                style={{ padding: "7px 14px", display: "inline-flex", alignItems: "center", gap: 6, cursor: "pointer" }}>
                <span style={{ fontSize: 13 }}>🔗</span>
                <span style={{ fontSize: useFontSize(11), fontWeight: 600, color: theme.textFeltMuted }}>Join Code</span>
              </GlassPanel>
              <GlassPanel dark radius={100} style={{ padding: "7px 12px", display: "inline-flex", alignItems: "center", gap: 5 }}>
                <span style={{ color: theme.accentSoft, fontSize: 12 }}>🪙</span>
                <span style={{ color: theme.textOnFelt, fontSize: useFontSize(12), fontWeight: 700, fontFamily: "'DM Serif Display', serif" }}>2,450</span>
              </GlassPanel>
              <ThemeSwitcher current={themeId} onChange={setThemeId} />
              <div style={{
                width: 36, height: 36, borderRadius: "50%",
                background: theme.avatarGradient,
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 18, border: `${theme.borderWidth}px solid ${theme.glassDarkBorder}`, cursor: "pointer",
              }}>😎</div>
            </div>
          </header>

          {/* ─── Welcome ─── */}
          <div style={{ margin: "4px 0 24px", animation: "fadeInUp 0.5s ease-out 0.08s both" }}>
            <h1 style={{ fontFamily: "'DM Serif Display', serif", fontSize: useFontSize(28), fontWeight: 400, color: theme.textOnFelt, marginBottom: 4, lineHeight: 1.2 }}>
              Pick a game
            </h1>
            <p style={{ fontSize: useFontSize(13), color: theme.textFeltMuted }}>
              Tap any game to see open rooms, tournaments, and jump right in.
            </p>
          </div>

          {/* Card Games */}
          <div style={{ animation: "fadeInUp 0.5s ease-out 0.15s both" }}>
            {renderSection(CARD_GAMES, "Card Games", "🃏", 200)}
          </div>

          {/* Board Games */}
          <div style={{ animation: "fadeInUp 0.5s ease-out 0.25s both" }}>
            {renderSection(BOARD_GAMES, "Board Games", "♟️", 550)}
          </div>

          {/* Global Tournaments */}
          <div style={{ animation: "fadeInUp 0.5s ease-out 0.35s both", marginBottom: 32 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
              <SectionLabel icon="🏆">Live &amp; Upcoming</SectionLabel>
              <span style={{ fontSize: useFontSize(11), color: theme.accent, fontWeight: 600, cursor: "pointer" }}>View all →</span>
            </div>
            <div className="scroll-h" style={{ display: "flex", gap: 12, paddingBottom: 8 }}>
              {globalTourneys.map((tt, i) => <GlobalTournamentCard key={i} data={tt} index={i} />)}
            </div>
          </div>

          {/* Bottom Nav */}
          <div style={{ position: "sticky", bottom: 0, padding: "10px 0 14px", background: theme.navGradient }}>
            <GlassPanel dark radius={18} style={{ display: "flex", justifyContent: "space-around", alignItems: "center", padding: "10px 6px" }}>
              {[
                { icon: "🏠", label: "Home", active: true },
                { icon: "🏆", label: "Compete" },
                { icon: "👥", label: "Friends" },
                { icon: "📊", label: "Stats" },
                { icon: "⚙️", label: "Settings" },
              ].map((nav) => (
                <div key={nav.label} style={{
                  display: "flex", flexDirection: "column", alignItems: "center",
                  gap: 2, cursor: "pointer", opacity: nav.active ? 1 : 0.45,
                  transition: "opacity 0.2s", minHeight: theme.minTouch || undefined, justifyContent: "center",
                }}>
                  <span style={{ fontSize: 18 }}>{nav.icon}</span>
                  <span style={{ fontSize: useFontSize(9), fontWeight: 600, color: nav.active ? theme.accentSoft : theme.textFeltMuted, letterSpacing: 0.2 }}>{nav.label}</span>
                  {nav.active && <div style={{ width: 4, height: 4, borderRadius: "50%", background: theme.accent, boxShadow: `0 0 8px ${theme.accent}` }} />}
                </div>
              ))}
            </GlassPanel>
          </div>
        </div>

        {/* Join Code Modal */}
        {joinCodeOpen && (
          <div onClick={() => setJoinCodeOpen(false)} style={{
            position: "fixed", inset: 0, background: theme.overlayBg,
            backdropFilter: "blur(6px)", display: "flex",
            alignItems: "center", justifyContent: "center", zIndex: 100,
          }}>
            <div onClick={(e) => e.stopPropagation()} style={{ animation: "fadeInUp 0.35s cubic-bezier(0.34,1.56,0.64,1)" }}>
              <GlassPanel radius={22} style={{
                padding: "26px 24px", width: 320, maxWidth: "90vw",
                background: theme.glassModalBg,
                border: `${theme.borderWidth}px solid ${theme.glassBorder}`,
              }}>
                <div style={{ fontFamily: "'DM Serif Display', serif", fontSize: useFontSize(20), color: theme.textDark, marginBottom: 4 }}>Join a Room</div>
                <div style={{ fontSize: useFontSize(12), color: theme.textMuted, marginBottom: 20 }}>Enter the room code shared by your friend.</div>
                <div style={{
                  display: "flex", alignItems: "center", gap: 10,
                  padding: "12px 16px", borderRadius: 14,
                  background: theme.inputBg, border: `${theme.borderWidth}px solid ${theme.inputBorder}`,
                  marginBottom: 18,
                }}>
                  <span style={{ fontSize: 18, color: theme.textMuted }}>🔗</span>
                  <input type="text" placeholder="XXXX-XX" value={joinCode}
                    onChange={(e) => setJoinCode(e.target.value.toUpperCase())} maxLength={7}
                    style={{
                      flex: 1, border: "none", outline: "none", background: "transparent",
                      fontFamily: "'DM Serif Display', serif",
                      fontSize: useFontSize(22), color: theme.textDark, letterSpacing: 4, textAlign: "center",
                    }} />
                </div>
                <AccentButton onClick={() => setJoinCodeOpen(false)}
                  style={{ width: "100%", justifyContent: "center", padding: 12, fontSize: useFontSize(14) }}>
                  Join Game
                </AccentButton>
              </GlassPanel>
            </div>
          </div>
        )}
      </div>
    </ThemeContext.Provider>
  );
}
