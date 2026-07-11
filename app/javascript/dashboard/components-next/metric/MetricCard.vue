<script setup>
/**
 * Compact metric tile: label + optional info tooltip + value, with a
 * layout-preserving loading state. Canonical replacement for the per-report
 * duplicates (CSAT / SLA / etc.) so every report shows metrics identically.
 */
import Skeleton from 'dashboard/components-next/skeleton/Skeleton.vue';

defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], required: true },
  tooltip: { type: String, default: '' },
  isLoading: { type: Boolean, default: false },
});
</script>

<template>
  <div class="flex flex-col items-start justify-center gap-2 min-w-[10rem]">
    <span
      class="inline-flex items-center gap-1 text-sm font-medium text-n-slate-11"
    >
      {{ label }}
      <span
        v-if="tooltip"
        v-tooltip.right="tooltip"
        class="flex flex-shrink-0 i-lucide-info text-n-slate-10 size-3.5"
      />
    </span>
    <Skeleton v-if="isLoading" width="w-16" height="h-8" />
    <span v-else class="text-2xl font-medium text-n-slate-12">
      {{ value }}
    </span>
  </div>
</template>
