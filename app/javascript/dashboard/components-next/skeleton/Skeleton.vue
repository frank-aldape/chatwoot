<script setup>
/**
 * Layout-preserving loading placeholder. Prefer this over a spinner for
 * content-shaped areas (lists, tables, cards, charts) so the UI reserves
 * space and the wait feels faster. The pulse animation is automatically
 * neutralized for users with `prefers-reduced-motion` (see _base.scss).
 *
 * Sizing/shape is driven by Tailwind utility classes passed as props so the
 * placeholder can match the real content it stands in for, e.g.
 *   <Skeleton width="w-24" height="h-8" />
 *   <Skeleton circle width="w-10" height="h-10" />
 */
defineProps({
  width: { type: String, default: 'w-full' },
  height: { type: String, default: 'h-4' },
  rounded: { type: String, default: 'rounded-md' },
  circle: { type: Boolean, default: false },
});

defineOptions({ inheritAttrs: false });
</script>

<template>
  <div
    v-bind="$attrs"
    aria-hidden="true"
    class="bg-n-slate-3 animate-pulse"
    :class="[width, height, circle ? 'rounded-full' : rounded]"
  />
</template>
