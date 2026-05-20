export interface DeviceProfile {
  viewport: { width: number; height: number };
  deviceScaleFactor: number;
  isMobile: boolean;
  hasTouch: boolean;
  userAgent?: string;
}

export const customDevices: Record<string, DeviceProfile> = {
  // ── Small Phones ──────────────────────────────────────────
  'iPhone SE': {
    viewport: { width: 375, height: 667 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  },

  // ── Medium Phones ─────────────────────────────────────────
  'iPhone 12': {
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
  },

  'iPhone 14': {
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
  },

  // ── Large Phones ──────────────────────────────────────────
  'iPhone 14 Pro Max': {
    viewport: { width: 430, height: 932 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
  },

  // ── Android Phones ────────────────────────────────────────
  'Pixel 5': {
    viewport: { width: 393, height: 851 },
    deviceScaleFactor: 2.75,
    isMobile: true,
    hasTouch: true,
  },

  'Samsung Galaxy S21': {
    viewport: { width: 360, height: 800 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
  },

  // ── Tablets ───────────────────────────────────────────────
  'iPad Mini': {
    viewport: { width: 768, height: 1024 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  },

  'iPad Pro 11': {
    viewport: { width: 834, height: 1194 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  },

  'iPad Pro 12.9': {
    viewport: { width: 1024, height: 1366 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  },

  // ── Foldables ─────────────────────────────────────────────
  'Samsung Galaxy Fold': {
    viewport: { width: 280, height: 653 }, // folded
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
  },

  'Samsung Galaxy Fold Unfolded': {
    viewport: { width: 717, height: 512 }, // unfolded landscape
    deviceScaleFactor: 2.625,
    isMobile: true,
    hasTouch: true,
  },

  // ── Desktop / Wide ────────────────────────────────────────
  'Desktop HD': {
    viewport: { width: 1920, height: 1080 },
    deviceScaleFactor: 1,
    isMobile: false,
    hasTouch: false,
  },

  '4K Display': {
    viewport: { width: 3840, height: 2160 },
    deviceScaleFactor: 2,
    isMobile: false,
    hasTouch: false,
  },

  'Ultrawide': {
    viewport: { width: 3440, height: 1440 },
    deviceScaleFactor: 1,
    isMobile: false,
    hasTouch: false,
  },
} as const;

export type DeviceName = keyof typeof customDevices;

/** Subset used in responsive smoke tests — covers the breadth of form factors. */
export const responsiveTestDevices: DeviceName[] = [
  'iPhone SE',
  'iPhone 12',
  'iPhone 14 Pro Max',
  'Pixel 5',
  'iPad Mini',
  'iPad Pro 12.9',
];

/** Devices where we verify touch target sizes (≥ 44 × 44 CSS px). */
export const touchDevices: DeviceName[] = [
  'iPhone SE',
  'iPhone 12',
  'iPhone 14 Pro Max',
  'Pixel 5',
  'Samsung Galaxy S21',
  'iPad Mini',
  'iPad Pro 12.9',
];
