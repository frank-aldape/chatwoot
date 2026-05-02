<script setup>
import { computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import FormInput from 'v3/components/Form/Input.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  isEditing: {
    type: Boolean,
    default: false,
  },
  isSubmitting: {
    type: Boolean,
    default: false,
  },
  managedCompany: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['close', 'submit']);
const { t } = useI18n();

const form = reactive({
  name: '',
  authorizedDomain: '',
  status: 'active',
});

const modalTitle = computed(() =>
  props.isEditing
    ? t('MANAGED_COMPANIES_SETTINGS.FORM.EDIT_TITLE')
    : t('MANAGED_COMPANIES_SETTINGS.FORM.CREATE_TITLE')
);

const submitLabel = computed(() =>
  props.isEditing
    ? t('MANAGED_COMPANIES_SETTINGS.FORM.UPDATE')
    : t('MANAGED_COMPANIES_SETTINGS.FORM.CREATE')
);

const resetForm = () => {
  form.name = props.managedCompany?.name || '';
  form.authorizedDomain = props.managedCompany?.authorized_domain || '';
  form.status = props.managedCompany?.status || 'active';
};

watch(
  () => [props.show, props.managedCompany],
  () => {
    resetForm();
  },
  { immediate: true, deep: true }
);

const handleClose = () => {
  emit('close');
};

const handleSubmit = () => {
  emit('submit', {
    name: form.name,
    authorizedDomain: form.authorizedDomain,
    status: form.status,
  });
};
</script>

<template>
  <woot-modal :show="show" :on-close="handleClose">
    <div class="flex flex-col w-full max-w-2xl p-6">
      <woot-modal-header :header-title="modalTitle" />

      <p class="mb-6 text-sm text-n-slate-11">
        {{ $t('MANAGED_COMPANIES_SETTINGS.FORM.DESCRIPTION') }}
      </p>

      <form class="grid gap-4" @submit.prevent="handleSubmit">
        <FormInput
          v-model="form.name"
          name="managed-company-name"
          spacing="compact"
          :label="$t('MANAGED_COMPANIES_SETTINGS.FORM.NAME_LABEL')"
          :placeholder="$t('MANAGED_COMPANIES_SETTINGS.FORM.NAME_PLACEHOLDER')"
        />
        <FormInput
          v-model="form.authorizedDomain"
          name="managed-company-domain"
          spacing="compact"
          :label="$t('MANAGED_COMPANIES_SETTINGS.FORM.DOMAIN_LABEL')"
          :placeholder="
            $t('MANAGED_COMPANIES_SETTINGS.FORM.DOMAIN_PLACEHOLDER')
          "
        />

        <label class="grid gap-2 text-sm font-medium text-n-slate-12">
          {{ $t('MANAGED_COMPANIES_SETTINGS.FORM.STATUS_LABEL') }}
          <select
            v-model="form.status"
            class="h-10 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
          >
            <option value="active">
              {{ $t('MANAGED_COMPANIES_SETTINGS.FORM.STATUS_ACTIVE') }}
            </option>
            <option value="inactive">
              {{ $t('MANAGED_COMPANIES_SETTINGS.FORM.STATUS_INACTIVE') }}
            </option>
          </select>
        </label>

        <div class="flex justify-end gap-2 pt-2">
          <Button
            type="button"
            slate
            :label="$t('MANAGED_COMPANIES_SETTINGS.FORM.CANCEL')"
            @click="handleClose"
          />
          <Button
            type="submit"
            :label="submitLabel"
            :is-loading="isSubmitting"
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>
