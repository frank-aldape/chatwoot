<script setup>
import { computed, useAttrs } from 'vue';
import Multiselect from 'vue-multiselect';

const props = defineProps({
  options: {
    type: Array,
    default: () => [],
  },
});

defineOptions({ inheritAttrs: false });

const attrs = useAttrs();

// Auto-enable search when there are more than 5 options.
// Respects an explicit :searchable prop if the parent passes one.
const autoSearchable = computed(() => {
  if (attrs.searchable !== undefined) return attrs.searchable;
  return (props.options || []).length > 5;
});
</script>

<template>
  <Multiselect v-bind="attrs" :options="options" :searchable="autoSearchable" />
</template>
