<script>
import Spinner from 'shared/components/Spinner.vue';

export default {
  components: {
    Spinner,
  },
  props: {
    loading: {
      type: Boolean,
      default: false,
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    color: {
      type: String,
      default: '#6e6f73',
    },
  },
};
</script>

<template>
  <button
    type="submit"
    :disabled="disabled"
    class="min-h-8 min-w-8 flex items-center justify-center ml-1"
  >
    <span
      v-if="!loading"
      class="i-lucide-send size-5"
      :style="`color: ${color}`"
    />
    <Spinner v-else size="small" />
  </button>
</template>
