<script setup>
defineProps({
  message: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div class="relative group w-[inherit] whitespace-normal z-20">
    <span class="i-lucide-info size-3.5 mt-0.5 text-n-slate-11 absolute" />
    <div
      class="bg-n-background w-fit ltr:left-4 rtl:right-4 top-0 border p-2.5 group-hover:flex items-center hidden absolute border-n-weak rounded-lg shadow-md"
    >
      <p class="text-n-slate-12 mb-0 text-xs">
        {{ message }}
      </p>
    </div>
  </div>
</template>
