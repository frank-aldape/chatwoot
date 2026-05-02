<script setup>
import { useI18n } from 'vue-i18n';
import ApiChannel from './Api.vue';

const { t } = useI18n();
</script>

<template>
  <ApiChannel
    :page-header-title="t('INBOX_MGMT.ADD.LINKEDIN.TITLE')"
    :page-header-description="t('INBOX_MGMT.ADD.LINKEDIN.DESC')"
    :channel-label="t('INBOX_MGMT.CHANNELS.LINKEDIN')"
    :submit-button-label="t('INBOX_MGMT.ADD.LINKEDIN.SUBMIT_BUTTON')"
    :error-message="t('INBOX_MGMT.ADD.LINKEDIN.API.ERROR_MESSAGE')"
    integration-slot="linkedin"
    :additional-attributes="{
      provider_type: 'linkedin',
      provider_label: 'LinkedIn',
    }"
  />
</template>
