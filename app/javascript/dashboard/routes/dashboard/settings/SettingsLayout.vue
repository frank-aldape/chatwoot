<script setup>
import Skeleton from 'dashboard/components-next/skeleton/Skeleton.vue';

defineProps({
  isLoading: {
    type: Boolean,
    default: false,
  },
  noRecordsFound: {
    type: Boolean,
    default: false,
  },
  loadingMessage: {
    type: String,
    default: '',
  },
  noRecordsMessage: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div class="flex flex-col w-full h-full gap-8 font-inter">
    <slot name="header" />
    <!-- Added to render any templates that should be rendered before body -->
    <main>
      <slot name="preBody" />
      <slot v-if="isLoading" name="loading">
        <div
          class="flex flex-col gap-3 py-4"
          role="status"
          :aria-label="loadingMessage"
        >
          <Skeleton
            v-for="n in 6"
            :key="n"
            height="h-12"
            rounded="rounded-lg"
          />
        </div>
      </slot>
      <p
        v-else-if="noRecordsFound"
        class="flex-1 py-20 text-n-slate-12 flex items-center justify-center text-base"
      >
        {{ noRecordsMessage }}
      </p>
      <slot v-else name="body" />
      <!-- Do not delete the slot below. It is required to render anything that is not defined in the above slots. -->
      <slot />
    </main>
  </div>
</template>
