---
name: ai-ui-design-standards
description: Apply a seven-rule AI UI design quality system derived from a Claude Design article. Use when Codex designs, critiques, or implements UI screens, high-fidelity mockups, web/mobile layouts, mini-program pages, landing pages, dashboards, or design-system guidance and should enforce spacing, hierarchy, readable text measure, responsive breakpoints, constraints, density, and minimum touch targets.
---

# AI UI Design Standards

Use this skill to produce or review UI work with a compact professional checklist. Treat the rules as hard quality gates unless the user provides a conflicting product/design-system requirement.

## Core workflow

1. Start by identifying the target surface: mobile, tablet, desktop, or responsive multi-breakpoint.
2. Define a design system before composing screens: spacing scale, typography hierarchy, color roles, container widths, component sizes, and interaction targets.
3. Apply the seven quality rules below while designing and again during review.
4. If implementing code, map every rule to concrete CSS/Tailwind values rather than leaving it as an aesthetic note.
5. In the final response, mention any rule intentionally relaxed and why.

## Seven UI quality rules

### 1. Use an 8-point spacing grid

Use spacing values based on multiples of 8px: 8, 16, 24, 32, 48, 64. Keep padding, margin, grid gaps, section spacing, and component rhythm consistent.

Distinguish clearly:
- Padding: space inside a component between content and border.
- Margin/gap: space between separate components or layout regions.

Implementation guidance:
- Prefer Tailwind spacing tokens such as `p-4`, `gap-4`, `mt-6`, `px-8` when they map cleanly to the 8px rhythm.
- Avoid arbitrary one-off values unless matching a supplied reference image pixel-perfectly.

### 2. Build a clear title hierarchy

Make primary headings, secondary headings, body copy, captions, and metadata visually distinct. The user should recognize the page purpose within one glance.

Check for:
- H1 is visibly stronger than subtitle/body text.
- Section titles are distinct from list item titles.
- Metadata is quieter through size, color, or weight.
- Important numbers/actions have sufficient emphasis.

### 3. Control text line width

Keep long-form text readable by constraining measure:
- English: roughly 60-75 characters per line.
- Chinese: roughly 30-38 characters per line.
- Recommended text container max width: about 600-700px for long-form desktop reading.

For mobile UI, avoid overly wide full-width paragraphs when a card or content column would improve scanability.

### 4. Use standard responsive breakpoints

Design and test against these baseline widths:
- Mobile: 375px.
- Tablet: 768px.
- Desktop: 1024px.

When implementing:
- Start with mobile-first layout.
- At tablet width, reconsider columns, navigation, and content density.
- At desktop width, add max-width constraints instead of stretching everything across the viewport.

### 5. Add reasonable constraints to every element

Prevent uncontrolled stretching or shrinking. Every major region should have a deliberate min/max behavior.

Apply constraints to:
- Overall page/container width.
- Text blocks and headings.
- Cards, panels, modals, sidebars, and tables.
- Images, charts, icons, avatars, and upload/drop zones.

Use max-width, min-width, aspect ratio, object-fit, overflow handling, and wrapping rules intentionally.

### 6. Describe compactness using density

Use density as the professional term for how tightly UI elements are arranged.

- Lower density: more breathing room, calmer reading, premium/editorial feel.
- Higher density: more information visible, better for data-heavy or operational screens.

When refining a UI, say exactly whether to increase or decrease density and which regions are affected: page, cards, lists, tables, navigation, forms, or hero sections.

### 7. Keep touch targets at least 44×44px

For mobile and touch interfaces, ensure every interactive element has a tappable target of at least 44×44px, even if the visible icon is smaller.

Apply this to:
- Buttons and icon buttons.
- Navigation items and tabs.
- Form controls.
- List rows that are clickable.
- Chips, pills, checkboxes, radio buttons, and menu triggers.

## Review checklist

Before delivering a UI, verify:
- Spacing follows an 8px rhythm.
- Heading hierarchy is obvious.
- Long text has a constrained line width.
- Layout works at 375px, 768px, and 1024px where relevant.
- Containers, media, and components have max/min constraints.
- Density matches the product goal.
- Touch/click targets are at least 44×44px on mobile.

## Output expectations

When designing:
- Provide concrete layout decisions, not vague aesthetic guidance.
- Include dimensions, spacing, typography scale, and responsive behavior.
- If creating code, encode the rules directly in CSS/Tailwind classes.

When reviewing:
- List violations by rule number.
- Explain the impact in user-facing terms.
- Provide the exact fix, e.g. `increase card padding from 12px to 16px`, `set max-width: 680px`, or `make icon button 44px square`.

For article-derived background and examples, read `references/source-summary.md` only if the user asks where the rules came from or wants the summarized source.
