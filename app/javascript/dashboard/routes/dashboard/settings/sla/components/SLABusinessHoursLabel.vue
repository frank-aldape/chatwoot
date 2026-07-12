<script setup>
defineProps({
  hasBusinessHours: {
    type: Boolean,
    required: true,
  },
});
</script>

<template>
  <div
    class="inline-flex items-center min-w-0 gap-1 px-1.5 sm:px-2 py-1 border border-solid rounded-lg border-n-weak"
  >
    <span
      class="flex-shrink-0 size-3.5"
      :class="[
        hasBusinessHours
          ? 'i-lucide-alarm-clock-check'
          : 'i-lucide-alarm-clock-off',
        hasBusinessHours ? 'text-n-slate-11' : 'text-n-slate-10',
      ]"
    />
    <span
      class="hidden text-xs tracking-[0.2%] font-normal truncate sm:block"
      :class="hasBusinessHours ? 'text-n-slate-11' : 'text-n-slate-10'"
    >
      {{
        hasBusinessHours
          ? $t('SLA.LIST.BUSINESS_HOURS_ON')
          : $t('SLA.LIST.BUSINESS_HOURS_OFF')
      }}
    </span>
  </div>
</template>
